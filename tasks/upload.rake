namespace :vox do
  desc 'Upload artifacts from the output directory to S3. Requires the AWS CLI to be installed and configured appropriately.'
  task :upload, [:tag, :platform] do |_, args|
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
    abort 'You must provide a tag.' if args[:tag].nil? || args[:tag].empty?

    munged_tag = args[:tag].gsub('-', '.')
    s3 = "aws s3 --endpoint-url=#{endpoint}"

    # Ensure the AWS CLI isn't going to fail with the given parameters
    run_command("#{s3} ls s3://#{bucket}/")

    glob = "#{__dir__}/../output/**/*#{munged_tag}*.{deb,rpm}"
    if os
      # "arch" is not used here because it's all noarch
      glob += "#{os}*"
    end
    files = Dir.glob(glob)
    abort 'No files for the given tag found in the output directory.' if files.empty?

    path = "s3://#{bucket}/#{component}/#{args[:tag]}"
    files.each do |f|
      #puts "Uploading #{File.basename(f)}"
      puts "#{s3} cp #{f} #{path}/#{File.basename(f)}"
      #run_command("#{s3} cp #{f} #{path}/#{File.basename(f)}")
    end
  end
end
