require 'fileutils'
require 'tmpdir'

@image = 'ezbake-builder'
@container = 'openvox-server-builder'
@timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
# It seems like these are special files/names that, when you want to add a new one, require
# changes in some other component.  But no, it seems to only really look at the parts of
# the text in the string, as long as it looks like "base-<whatever you want to call the platform>-i386.cow"
# and "<doesn't matter>-<os>-<osver>-<arch which doesn't matter because it's actually noarch>".
# I think it just treats all debs like Debian these days. And all rpms are similar.
# So do whatever you want I guess. We really don't need separate packages for each platform.
# To be fixed one of these days. Relevant stuff:
#   https://github.com/puppetlabs/ezbake/blob/aeb7735a16d2eecd389a6bd9e5c0cfc7c62e61a5/resources/puppetlabs/lein-ezbake/template/global/tasks/build.rake
#   https://github.com/puppetlabs/ezbake/blob/aeb7735a16d2eecd389a6bd9e5c0cfc7c62e61a5/resources/puppetlabs/lein-ezbake/template/global/ext/fpm.rb
#
# Note: This is not the canonical list of supported OpenVox platforms. Look at https://github.com/OpenVoxProject/shared-actions/blob/8f4d7e99f5e8a23f48e07124aa9adbb9768fabb9/.github/workflows/build_ezbake.yml#L36-L37
deb_platforms = ENV['DEB_PLATFORMS'] || 'ubuntu-20.04,ubuntu-22.04,ubuntu-24.04,ubuntu-25.04,ubuntu-25.10,debian-11,debian-12,debian-13'
@debs = deb_platforms.split(',').map{ |p| "base-#{p.split('-').join}-i386.cow" }.join(' ')

rpm_platforms = ENV['RPM_PLATFORMS'] || 'el-8,el-9,el-10,sles-15,sles-16,amazon-2,amazon-2023,fedora-42,fedora-43'
rpm_fips, rpm_nonfips = rpm_platforms.split(',').partition { |p| p.start_with?('redhatfips') }
@nonfips_rpms = rpm_nonfips.map{ |p| "pl-#{p}-x86_64" }.join(' ')
@fips_rpms = rpm_fips.map{ |p| "pl-#{p}-x86_64" }.join(' ')

# The deps must be built in this order due to dependencies between them.
# There is a circular dependency between clj-http-client and trapperkeeper-webserver-jetty10,
# but only for tests, so the build *should* work.
DEP_BUILD_ORDER = [
  'clj-kitchensink',
  'clj-i18n',
  'comidi',
  'jvm-ssl-utils',
  'clj-typesafe-config',
  'jruby-deps',
  'trapperkeeper',
  'trapperkeeper-filesystem-watcher',
  'clj-http-client',
  'trapperkeeper-webserver-jetty10',
  'ring-middleware',
  'jruby-utils',
  'clj-shell-utils',
  'dujour-version-check',
  'clj-rbac-client',
  'trapperkeeper-authorization',
  'trapperkeeper-metrics',
  'trapperkeeper-scheduler',
  'trapperkeeper-status',
  'trapperkeeper-comidi-metrics',
].freeze

def image_exists
  !`docker images -q #{@image}`.strip.empty?
end

def container_exists
  !`docker container ls --all --filter 'name=#{@container}' --format json`.strip.empty?
end

def teardown
  if container_exists
    puts "Stopping #{@container}"
    run_command("docker stop #{@container}", silent: false, print_command: true)
    run_command("docker rm #{@container}", silent: false, print_command: true)
  end
end

def start_container(ezbake_dir)
  run_command("docker run -d --name #{@container} -v .:/code -v #{ezbake_dir}:/deps #{@image} /bin/sh -c 'tail -f /dev/null'", silent: false, print_command: true)
end

def run(cmd)
  run_command("docker exec #{@container} /bin/bash --login -c '#{cmd}'", silent: false, print_command: true)
end

namespace :vox do
  desc 'Build openvox-server packages with Docker'
  task :build, [:tag] do |_, args|
    begin
      #abort 'You must provide a tag.' if args[:tag].nil? || args[:tag].empty?
      if args[:tag].nil? || args[:tag].empty?
        puts 'running build with current branch'
      else
        puts "running build on #{args[:tag]}"
        run_command("git fetch --tags && git checkout #{args[:tag]}")
      end

      # If the Dockerfile has changed since this was last built,
      # delete all containers and do `docker rmi ezbake-builder`
      unless image_exists
        puts "Building ezbake-builder image"
        run_command("docker build -t ezbake-builder .", silent: false, print_command: true)
      end

      libs_to_build_manually = {}
      if ENV['EZBAKE_BRANCH'] && !ENV['EZBAKE_BRANCH'].strip.empty?
        libs_to_build_manually['ezbake'] = {
          :repo => ENV.fetch('EZBAKE_REPO', 'https://github.com/openvoxproject/ezbake'),
          :branch => ENV.fetch('EZBAKE_BRANCH', 'main'),
        }
      end

      deps_to_build = []
      dep_branch = nil

      full_rebuild_branch = ENV['FULL_DEP_REBUILD_BRANCH']
      subset_list = (ENV['DEP_REBUILD'] || '').split(',').map(&:strip).reject(&:empty?)
      subset_branch = ENV.fetch('DEP_REBUILD_BRANCH', 'main').to_s
      rebuild_org = ENV.fetch('DEP_REBUILD_ORG', 'openvoxproject').to_s

      if full_rebuild_branch && !full_rebuild_branch.strip.empty?
        dep_branch = full_rebuild_branch.strip
        deps_to_build = DEP_BUILD_ORDER.dup
      elsif !subset_list.empty?
        dep_branch = subset_branch
        unknown = subset_list.reject { |lib| DEP_BUILD_ORDER.include?(lib) }
        puts "WARNING: Unknown deps in DEP_REBUILD (will be ignored): #{unknown.join(', ')}" unless unknown.empty?
        deps_to_build = DEP_BUILD_ORDER.select { |lib| subset_list.include?(lib) }
      end

      deps_to_build.each do |lib|
        libs_to_build_manually[lib] = {
          :repo => "https://github.com/#{rebuild_org}/#{lib}",
          :branch => dep_branch,
        }
      end

      deps_tmp = Dir.mktmpdir("deps")

      libs_to_build_manually.each do |lib, config|
        puts "Checking out #{lib}"
        # to be able to checkout github refs, e.g. 66/merge, we need to do an explicit fetch
        # this allows us to test on branches from pull requests
        # we can probably switch to git clone --revision $ref $url in the future, but that requires a newer git. EL9 is too old
        run_command("git clone --no-checkout #{config[:repo]} #{deps_tmp}/#{lib}; cd #{deps_tmp}/#{lib}; git fetch origin #{config[:branch]}; git checkout FETCH_HEAD", silent: false, print_command: true)
      end

      puts "Starting container"
      teardown if container_exists
      start_container(deps_tmp)

      libs_to_build_manually.each do |lib, _|
        puts "Building and installing #{lib} from source"
        run("cd /deps/#{lib} && lein install")
      end

      puts "Building openvox-server"
      ezbake_version_var = ENV['EZBAKE_VERSION'] ? "EZBAKE_VERSION=#{ENV['EZBAKE_VERSION']}" : ''
      run("cd /code && rm -rf output && bundle install --without test && lein install")

      unless @debs.empty? && @nonfips_rpms.empty?
        run("cd /code && COW=\"#{@debs}\" MOCK=\"#{@nonfips_rpms}\" GEM_SOURCE='https://rubygems.org' #{ezbake_version_var} EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile user,ezbake,provided ezbake local-build")
      end
      
      # When building for FIPS, we have to have the Bouncy Castle FIPS jars live on disk separate
      # from the uberjar, due to signing of those jars. Ezbake doesn't have a great way to handle this,
      # so we copy them from the local Maven cache inside the container to a place ezbake knows how to
      # find them, and then have it build the RPM with it laying down those files in the right place.
      unless @fips_rpms.empty?
        puts "Copy Bouncy Castle FIPS jars into ezbake resource location"
        dest = '/code/resources/ext/build-scripts/bc-fips-jars'
        run("mkdir -p #{dest}")
        cmd = "cd /code && lein with-profile ezbake-fips,fips classpath"
        stdout, stderr, status = Open3.capture3("docker exec #{@container} /bin/bash --login -c '#{cmd}'")
        unless status.success?
          puts "Failed to get classpath for FIPS build: #{stderr}"
          exit 1
        end
        classpath = stdout.strip
        paths = classpath.split(':').select { |p| p =~ /bcpkix-fips|bc-fips|bctls-fips/ }
        paths.each { |p| run("cp #{p} #{dest}/") }

        # We also copy the non-FIPS jdk18on jars as well. This is only for the step where we install
        # vendored gems during the packaging step and they are not included in the final package.
        dest = '/code/resources/ext/build-scripts/bc-nonfips-jars'
        run("mkdir -p #{dest}")
        paths = classpath.split(':').select { |p| p =~ /jdk18on/ }
        paths.each { |p| run("cp #{p} #{dest}/") }

        run("cd /code && COW= MOCK=\"#{@fips_rpms}\" GEM_SOURCE='https://rubygems.org' #{ezbake_version_var} EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile fips,user,ezbake-fips,provided ezbake local-build")
      end

      run_command("sudo chown -R $USER output", print_command: true)
      Dir.glob('output/**/*i386*').each { |f| FileUtils.rm_rf(f) }
      Dir.glob('output/puppetserver-*.tar.gz').each { |f| FileUtils.mv(f, f.sub('puppetserver','openvox-server'))}
      # If this is a FIPS-only build, we don't want the upload task to overwrite the existing tarball on S3.
      # This tarball should be basically identical, but we want to keep both for clarity.
      if !@fips_rpms.empty? && @debs.empty? && @nonfips_rpms.empty?
        Dir.glob('output/openvox-server-*.tar.gz').each { |f| FileUtils.mv(f, f.sub('.tar.gz','-fips_build.tar.gz'))}
      end
    ensure
      teardown
      FileUtils.rm_rf("#{__dir__}/../resources/ext/build-scripts/bc-fips-jars") unless @fips_rpms.empty?
      FileUtils.rm_rf("#{__dir__}/../resources/ext/build-scripts/bc-nonfips-jars") unless @fips_rpms.empty?
    end
  end
end
