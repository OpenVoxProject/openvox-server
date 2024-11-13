require 'open3'
require 'fileutils'

namespace :overlookinfra do
  desc "Build this project with the given tag. This should be the puppetlabs tag for the release."
  task :build, [:tag] do |t, args|
    if args[:tag].nil? || args[:tag].empty?
      abort "You must provide a tag."
    end

    # We don't yet need to do this. When we have our own version of ezbake, we will
    # need to check it out and install it in the container (unless we have it uploaded in a different
    # namespace that can be pulled down automatically) and then modify the project.clj
    # file to use that ezbake instead.
    #puts "Checking out git@github.com:overlookinfra/ezbake"
    #ezbake = "#{__dir__}/../ezbake"
    #FileUtils.rm_rf(ezbake)
    #run_command("git clone git@github.com:overlookinfra/ezbake #{ezbake} && cd #{ezbake} && git checkout main")
    
    cmd = "GEM_SOURCE=\"https://rubygems.org\" #{__dir__}/../build-ezbake.rb puppetserver #{args[:tag]}"
    puts "Running #{cmd}"
    Open3.popen2e(cmd) do |stdin, stdout_stderr, thread|
      stdout_stderr.each { |line| puts line }
      exit_status = thread.value
      puts "Command finished with status #{exit_status.exitstatus}"
    end
  end
end

def run_command(cmd)
  output, status = Open3.capture2e(cmd)
  abort "Command failed! Command: #{cmd}, Output: #{output}" unless status.exitstatus.zero?
  return output.chomp
end