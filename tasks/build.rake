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
deb_platforms = ENV['DEB_PLATFORMS'] || 'ubuntu-20.04,ubuntu-22.04,ubuntu-24.04,ubuntu-25.04,debian-11,debian-12,debian-13'
rpm_platforms = ENV['RPM_PLATFORMS'] || 'el-8,el-9,el-10,sles-15,sles-16,amazon-2,amazon-2023,fedora-42,fedora-43'
@debs = deb_platforms.split(',').map{ |p| "base-#{p.split('-').join}-i386.cow" }.join(' ')
@rpms = rpm_platforms.split(',').map{ |p| "pl-#{p}-x86_64" }.join(' ')

# The deps must be built in this order due to dependencies between them.
# There is a circular dependency between clj-http-client and trapperkeeper-webserver-jetty10,
# but only for tests, so the build *should* work.
DEP_BUILD_ORDER = [
  'clj-parent',
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

      fips = !ENV['FIPS'].nil?
      puts "Building openvox-server"
      ezbake_version_var = ENV['EZBAKE_VERSION'] ? "EZBAKE_VERSION=#{ENV['EZBAKE_VERSION']}" : ''
      run("cd /code && rm -rf output && bundle install --without test && lein install")
      run("cd /code && COW=\"#{@debs}\" MOCK=\"#{@rpms}\" GEM_SOURCE='https://rubygems.org' #{ezbake_version_var} EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile #{fips ? 'fips,' : ''}user,ezbake,provided,internal ezbake local-build")
      run_command("sudo chown -R $USER output", print_command: true)
      Dir.glob('output/**/*i386*').each { |f| FileUtils.rm_rf(f) }
      Dir.glob('output/puppetserver-*.tar.gz').each { |f| FileUtils.mv(f, f.sub('puppetserver','openvox-server'))}
    ensure
      teardown
    end
  end
end
