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

namespace :vox do
  desc 'Build openvox-server packages with Docker'
  task :build, [:tag] do |_, args|
    if args[:tag].nil? || args[:tag].empty?
      puts 'running build with current branch'
    else
      puts "running build on #{args[:tag]}"
      run_command("git fetch --tags && git checkout #{args[:tag]}")
    end

    puts "Checking out ezbake"
    tmp = Dir.mktmpdir("ezbake")
    ezbake_dir = "#{tmp}/ezbake"
    ezbake_repo = ENV.fetch('EZBAKE_REPO', 'https://github.com/openvoxproject/ezbake')
    ezbake_branch = ENV['EZBAKE_BRANCH'] || 'main'
    run_command("git clone -b #{ezbake_branch} #{ezbake_repo} #{ezbake_dir}", silent: false, print_command: true)

    # prepare git foo for packaging gem (????)
    run_command("git config --global user.email 'you@example.com'; git config --global user.name 'Your Name'")

    puts "Installing ezbake from source"
    run_command("cd #{ezbake_dir} && lein install", silent: false, print_command: true)

    puts "Building openvox-server"
    run_command("rm -rf ruby && rm -rf output && bundle install --without test && lein install", silent: false, print_command: true)
    run_command("COW=\"#{@debs}\" MOCK=\"#{@rpms}\" GEM_SOURCE='https://rubygems.org' EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile user,ezbake,provided ezbake local-build", silent: false, print_command: true)
    run_command("sudo chown -R $USER output", print_command: true)
    Dir.glob('output/**/*i386*').each { |f| FileUtils.rm_rf(f) }
    Dir.glob('output/puppetserver-*.tar.gz').each { |f| FileUtils.mv(f, f.sub('puppetserver','openvox-server'))}
  end
end
