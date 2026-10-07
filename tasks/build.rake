require 'fileutils'
require 'tmpdir'
require_relative '../packaging/lib/server_packaging'

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
deb_platforms = ENV['DEB_PLATFORMS'] || 'ubuntu-22.04,ubuntu-24.04,ubuntu-26.04,debian-13'
@debs = deb_platforms.split(',').map{ |p| "base-#{p.split('-').join}-i386.cow" }.join(' ')

rpm_platforms = ENV['RPM_PLATFORMS'] || 'el-8,el-9,el-10,sles-15,sles-16,amazon-2023,fedora-43,fedora-44'
rpm_fips, rpm_nonfips = rpm_platforms.split(',').partition { |p| p.start_with?('redhatfips') }
@nonfips_rpms = rpm_nonfips.map{ |p| "pl-#{p}-x86_64" }.join(' ')
@fips_rpms = rpm_fips.map{ |p| "pl-#{p}-x86_64" }.join(' ')

OUTPUT_DIR = File.expand_path('../packaging/output', __dir__)

def image_exists
  !`${DOCKER_BIN-docker} images -q #{@image} --format='{{json .ID}}'`.strip.empty?
end

def container_exists
  !`${DOCKER_BIN-docker} container ls --all --filter 'name=#{@container}' --format '{{json .ID}}'`.strip.empty?
end

def teardown
  if container_exists
    puts "Stopping #{@container}"
    run_command("${DOCKER_BIN-docker} stop #{@container}", silent: false, print_command: true)
    run_command("${DOCKER_BIN-docker} rm #{@container}", silent: false, print_command: true)
  end
end

def start_container(ezbake_dir)
  run_command("${DOCKER_BIN-docker} run -d --name #{@container} -v .:/code -v #{ezbake_dir}:/deps #{@image} /bin/sh -c 'tail -f /dev/null'", silent: false, print_command: true)
end

def run(cmd)
  run_command("${DOCKER_BIN-docker} exec #{@container} /bin/bash --login -c '#{cmd}'", silent: false, print_command: true)
end

# Mirrors vanagon's Project::DSL#version_from_git so the uberjar archive name
# computed here matches the one the vanagon projects compute for the same ref
def server_package_version
  return ENV['OPENVOX_SERVER_VERSION'] unless ENV['OPENVOX_SERVER_VERSION'].to_s.empty?

  describe = run_command('git describe --tags --abbrev=9')
  case describe
  when /\A\d+\.\d+\.\d+-(?:alpha|beta|rc)\d+\z/
    describe.sub('-', '~')
  else
    describe.split('-').reject(&:empty?).join('.')
  end
end

# Runs the vanagon build for one project and platform. Outside CI a build of
# openvox-server first builds the uberjar archive it needs when that is
# missing from packaging/output, then points vanagon at that directory. In CI
# the uberjar job has already uploaded the archive, so the openvox-server
# project falls back to the artifacts bucket URL for this version.
def vanagon_build(project, build_platform)
  abort "Unexpected project name #{project}" unless project.match?(/\A[a-z0-9-]+\z/)
  abort "Unexpected platform #{build_platform}" unless build_platform.match?(/\A[a-z0-9._-]+\z/)

  ENV['SOURCE_DATE_EPOCH'] ||= run_command('git log -1 --format=%ct')

  if project == 'openvox-server' && ENV['SERVER_TARBALL_BASE'].to_s.empty? && ENV['GITHUB_ACTIONS'] != 'true'
    variant = ServerPackaging.uberjar_variant(build_platform)
    archive = File.join(OUTPUT_DIR, ServerPackaging.uberjar_archive_name(server_package_version, variant))
    vanagon_build('openvox-server-uberjar', ServerPackaging::UBERJAR_PLATFORMS.fetch(variant)) unless File.exist?(archive)
    ENV['SERVER_TARBALL_BASE'] = "file://#{OUTPUT_DIR}"
  end

  Dir.chdir(File.expand_path('../packaging', __dir__)) do
    run_command("bundle exec vanagon build #{project} #{build_platform} --engine docker",
                silent: false, print_command: true, report_status: true)
  end
end

namespace :vox do
  desc 'Build openvox-server packages. Project and platform args run the vanagon build, a single ref arg runs the transitional ezbake build.'
  task :build, [:tag, :platform] do |_, args|
    if args[:platform] && !args[:platform].to_s.empty?
      vanagon_build(args[:tag] || 'openvox-server', args[:platform])
      next
    end

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
        run_command("${DOCKER_BIN-docker} build -t ezbake-builder .", silent: false, print_command: true)
      end

      libs_to_build_manually = {}
      if ENV['EZBAKE_BRANCH'] && !ENV['EZBAKE_BRANCH'].strip.empty?
        libs_to_build_manually['ezbake'] = {
          :repo => ENV.fetch('EZBAKE_REPO', 'https://github.com/openvoxproject/ezbake'),
          :branch => ENV.fetch('EZBAKE_BRANCH', 'main'),
        }
      end

      deps_to_build, dep_branch, rebuild_org = ServerPackaging.clojure_dep_rebuild
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
      run("cd /code && rm -rf output && bundle config set without test && bundle install && lein install")

      unless @debs.empty? && @nonfips_rpms.empty?
        run("cd /code && COW=\"#{@debs}\" MOCK=\"#{@nonfips_rpms}\" GEM_SOURCE='https://rubygems.org' #{ezbake_version_var} EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile user,ezbake,provided ezbake local-build")
      end

      unless @fips_rpms.empty?
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
