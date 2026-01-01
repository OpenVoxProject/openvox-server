namespace :vox do
  desc 'Upload artifacts from the output directory to S3. Requires the AWS CLI to be installed and configured appropriately.'
  task :upload, [:platform] do |_, args|
    endpoint = ENV.fetch('ENDPOINT_URL')
    bucket = ENV.fetch('BUCKET_NAME')
    component = 'openvox-server'
    os = nil
    arch = nil
    if args[:platform]
      parts = args[:platform].split('-')
      os = parts[0].gsub('fedora','fc') + parts[1]
      arch = parts[2]
    end

    abort 'You must set the ENDPOINT_URL environment variable to the S3 server you want to upload to.' if endpoint.nil? || endpoint.empty?
    abort 'You must set the BUCKET_NAME environment variable to the S3 bucket you are uploading to.' if bucket.nil? || bucket.empty?

    s3 = "aws s3 --endpoint-url=#{endpoint}"

    # Ensure the AWS CLI isn't going to fail with the given parameters
    run_command("#{s3} ls s3://#{bucket}/")

    config = File.expand_path("../target/staging/ezbake.rb", __dir__)
    abort "Could not find ezbake config from the build at #{config}" unless File.exist?(config)
    load config
    version = EZBake::Config.fetch(:version)
    release = EZBake::Config.fetch(:release)
    # If release is a digit, then we built a tagged version. Otherwise,
    # we built a snapshot and want to include that in the path to upload to.
    tag = release =~ /^\d{1,2}$/ ? version : "#{version}-#{release}"


    glob = "#{__dir__}/../output/**/*#{tag}*"
    if os
      # "arch" is not used here because it's all noarch
      glob += "#{os}*"
    end
    files = Dir.glob(glob)
    abort 'No files for the given tag found in the output directory.' if files.empty?

    path = "s3://#{bucket}/#{component}/#{tag}"
    files.each do |f|
      run_command("#{s3} cp #{f} #{path}/#{File.basename(f)}", silent: false)
    end
  end
end
