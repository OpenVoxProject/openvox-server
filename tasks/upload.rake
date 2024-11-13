require 'open3'

namespace :overlookinfra do
  desc "Upload artifacts from the output directory to S3. Requires the AWS CLI to be installed and configured appropriately."
  task :upload, [:tag] do |t, args|
    endpoint = ENV['ENDPOINT_URL']
    bucket = ENV['BUCKET_NAME']

    if endpoint.nil? || endpoint.empty?
      abort "You must set the ENDPOINT_URL environment variable to the S3 server you want to upload to."
    end
    if bucket.nil? || bucket.empty?
      abort "You must set the BUCKET_NAME environment variable to the S3 bucket you are uploading to."
    end
    if args[:tag].nil? || args[:tag].empty?
      abort "You must provide a tag."
    end
    munged_tag = args[:tag].gsub('-','.')
    s3 = "aws s3 --endpoint-url=#{endpoint}"

    # Ensure the AWS CLI isn't going to fail with the given parameters
    run_command("#{s3} ls s3://#{bucket}/")

    files = Dir.glob("#{__dir__}/../output/**/*#{munged_tag}*")
    if files.empty?
      puts "No files for the given tag found in the output directory."
    end
    path = "s3://#{bucket}/puppetserver/#{args[:tag]}"
    files.each do |f|
      puts "Uploading #{File.basename(f)}"
      run_command("#{s3} cp #{f} #{path}/#{File.basename(f)} --endpoint-url=#{endpoint}")
    end
  end
end

def run_command(cmd)
  output, status = Open3.capture2e(cmd)
  abort "Command failed! Command: #{cmd}, Output: #{output}" unless status.exitstatus.zero?
  return output.chomp
end