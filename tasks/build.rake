require 'fileutils'

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
# Also, these probably shouldn't live here long-term and be passed in so a GitHub Action can
# determine which platforms to build packages for.
@debs = "base-ubuntu18.04-i386.cow base-ubuntu20.04-i386.cow base-ubuntu22.04-i386.cow base-ubuntu24.04-i386.cow base-debian10-i386.cow base-debian11-i386.cow base-debian12-i386.cow"
@rpms = "pl-el-7-x86_64 pl-el-8-x86_64 pl-el-9-x86_64 pl-el-10-x86_64 pl-sles-15-x86_64 pl-amazon-2023-x86_64"

def image_exists
  !`docker images -q #{@image}`.strip.empty?
end

def container_exists
  !`docker container ls --all --filter 'name=#{@container}' --format json`.strip.empty?
end

def teardown
  if container_exists
    puts "Stopping #{@container}"
    run_command("docker stop #{@container}")
    run_command("docker rm #{@container}")
  end
end

def start_container(ezbake_dir)
  run_command("docker run -d --name #{@container} -v .:/code -v #{ezbake_dir}:/ezbake #{@image} /bin/sh -c 'tail -f /dev/null'")
end

def run(cmd)
  puts "\033[32mRunning #{cmd}\033[0m"
  run_command("docker exec #{@container} /bin/bash --login -c '#{cmd}'")
end

namespace :vox do
  desc 'Build openvox-server packages with Docker'
  task :build, [:tag] do |_, args|
    begin
      abort 'You must provide a tag.' if args[:tag].nil? || args[:tag].empty?
      run_command("git checkout #{args[:tag]}")
      
      # If the Dockerfile has changed since this was last built,
      # delete all containers and do `docker rmi ezbake-builder`
      unless image_exists
        puts "Building ezbake-builder image"
        run_command("docker build -t ezbake-builder .")
      end

      puts "Checking out ezbake"
      tmp = Dir.mktmpdir("ezbake")
      ezbake_dir = "#{tmp}/ezbake"
      run_command("git clone https://github.com/openvoxproject/ezbake #{ezbake_dir}")
      Dir.chdir(ezbake_dir) { |_| run_command('git checkout main') }

      puts "Starting container"
      teardown if container_exists
      start_container(ezbake_dir)

      puts "Installing ezbake from source"
      run("cd /ezbake && lein install")

      puts "Building openvox-server"
      run("cd /code && rm -rf ruby && rm -rf output && bundle install --without test && lein install")
      run("cd /code && COW=\"#{@debs}\" MOCK=\"#{@rpms}\" GEM_SOURCE='https://rubygems.org' EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile user,ezbake,provided,internal ezbake local-build")
      Dir.glob('output/*i386*').each { |f| FileUtils.rm_rf(f) }
      Dir.glob('output/puppetserver-*.tar.gz').each { |f| FileUtils.mv(f, f.sub('puppetserver','openvox-server'))}
    ensure
      teardown
    end
  end
end