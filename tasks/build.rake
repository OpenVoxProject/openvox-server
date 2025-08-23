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
deb_platforms = ENV['DEB_PLATFORMS'] || 'ubuntu-18.04,ubuntu-20.04,ubuntu-22.04,ubuntu-24.04,debian-10,debian-11,debian-12'
rpm_platforms = ENV['RPM_PLATFORMS'] || 'el-7,el-8,el-9,el-10,sles-15,amazon-2023'
@debs = deb_platforms.split(',').map{ |p| "base-#{p.split('-').join}-i386.cow" }.join(' ')
@rpms = rpm_platforms.split(',').map{ |p| "pl-#{p}-x86_64" }.join(' ')

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
  run_command("docker run -d --name #{@container} -v .:/code -v #{ezbake_dir}:/ezbake #{@image} /bin/sh -c 'tail -f /dev/null'", silent: false, print_command: true)
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

      puts "Checking out ezbake"
      tmp = Dir.mktmpdir("ezbake")
      ezbake_dir = "#{tmp}/ezbake"
      ezbake_repo = ENV.fetch('EZBAKE_REPO', 'https://github.com/openvoxproject/ezbake')
      ezbake_branch = ENV['EZBAKE_BRANCH'] || 'main'
      run_command("git clone -b #{ezbake_branch} #{ezbake_repo} #{ezbake_dir}", silent: false, print_command: true)

      puts "Starting container"
      teardown if container_exists
      start_container(ezbake_dir)

      puts "Installing ezbake from source"
      run("cd /ezbake && lein install")

      puts "Building openvox-server"
      ezbake_version_var = ENV['EZBAKE_VERSION'] ? "EZBAKE_VERSION=#{ENV['EZBAKE_VERSION']}" : ''
      run("cd /code && rm -rf ruby && rm -rf output && bundle install --without test && lein install")
      run("cd /code && COW=\"#{@debs}\" MOCK=\"#{@rpms}\" GEM_SOURCE='https://rubygems.org' #{ezbake_version_var} EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile user,ezbake,provided,internal ezbake local-build")
      run_command("sudo chown -R $USER output", print_command: true)
      Dir.glob('output/**/*i386*').each { |f| FileUtils.rm_rf(f) }
      Dir.glob('output/puppetserver-*.tar.gz').each { |f| FileUtils.mv(f, f.sub('puppetserver','openvox-server'))}
    ensure
      teardown
    end
  end
end
