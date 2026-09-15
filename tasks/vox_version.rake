###
# stolen from tag.rake
###
def vox_set_version(version)
  data = File.read('project.clj')
#(defproject org.openvoxproject/puppetserver "9.1.0-SNAPSHOT"
#  data = data.sub(/\(def ps-version "[^"]*"/,"(def ps-version \"#{version}\"")
  data = data.sub /\(defproject org.openvoxproject\/puppetserver .*-SNAPSHOT\"/, "(defproject org.openvoxproject/puppetserver \"#{version}-SNAPSHOT\""
  File.write('project.clj', data)
  require_relative '../scripts/sync_ezbake_dep.rb'
  run_command("git add project.clj && git commit -m 'Set version to #{version}'", silent: true)
end

namespace :vox do
  desc 'Update the version in preparation for a release'
  task 'version:bump:fullmarcuswarhier', [:version] do |_, args|
    abort 'You must provide a tag.' if args[:version].nil? || args[:version].empty?
    version = args[:version]
    #VERSION_PATTERN = '[0-9]+(?>\.[0-9a-zA-Z]+)*(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?' # :nodoc:
    #ANCHORED_VERSION_PATTERN = /\A\s*(#{VERSION_PATTERN})?\s*\z/ # :nodoc:
    abort "#{version} does not appear to be a valid version string in x.y.z format" unless Gem::Version.correct?(version)

    # Update lib/puppet/version.rb and openvox.gemspec
    puts "Setting version to #{version}"


    vox_set_version :version

  end
end
