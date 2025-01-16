def set_version(version)
  data = File.read('project.clj')
  data = data.sub(/\(def ps-version "[^"]*"/,"(def ps-version \"#{version}\"")
  File.write('project.clj', data)
  run_command("git add project.clj && git commit -m 'Set version to #{version}'")
end

namespace :vox do
  desc 'Create tag and push to origin'
  task :tag, [:tag] do |_, args|
    abort 'You must provide a tag.' if args[:tag].nil? || args[:tag].empty?
    abort "#{args[:tag]} does not appear to be a valid version string in x.y.z format" unless Gem::Version.correct?(args[:tag])
    version = Gem::Version.new(args[:tag])
    snapshot_version = Gem::Version.new("#{args[:tag]}.0").bump # bump will only bump the next-to-last number

    # Update project.clj to set the version to the tag
    puts "Setting version to #{version}"
    set_version(version)

    # Run git command to get short SHA and one line description of the commit on HEAD
    branch = run_command('git rev-parse --abbrev-ref HEAD')
    sha = run_command('git rev-parse --short HEAD')
    msg = run_command('git log -n 1 --pretty=%B')

    puts "Branch: #{branch}"
    puts "SHA: #{sha}"
    puts "Commit: #{msg}"

    run_command("git tag -a #{args[:tag]} -m '#{args[:tag]}'")

    puts "Setting version after tag to #{snapshot_version}"
    set_version("#{snapshot_version}-SNAPSHOT")

    puts "Pushing to origin"
    run_command("git push origin && git push origin #{args[:tag]}")
  end
end