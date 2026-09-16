def s3_command_prefix
  endpoint = ENV.fetch('ENDPOINT_URL', nil)
  bucket = ENV.fetch('BUCKET_NAME', nil)
  abort 'You must set the ENDPOINT_URL environment variable to the S3 server you want to upload to.' if endpoint.nil? || endpoint.empty?
  abort 'You must set the BUCKET_NAME environment variable to the S3 bucket you are uploading to.' if bucket.nil? || bucket.empty?

  s3 = "aws s3 --endpoint-url=#{endpoint}"
  # Ensure the AWS CLI isn't going to fail with the given parameters
  run_command("#{s3} ls s3://#{bucket}/")
  [s3, bucket]
end

def s3_upload_files(files, tag)
  s3, bucket = s3_command_prefix
  path = "s3://#{bucket}/openvox-server/#{tag}"
  files.each do |f|
    run_command("#{s3} cp #{f} #{path}/#{File.basename(f)} --no-progress", silent: false)
  end
end

# Uploads the vanagon build output for one platform, or everything in
# packaging/output when no platform is given. Packages carry the short
# platform tag in their names (el9, ubuntu24.04) while the uberjar archives
# carry the full vanagon platform name (el-9-x86_64).
def vanagon_upload(tag, platform)
  munged_tag = tag.gsub('-', '.')
  glob = "#{__dir__}/../packaging/output/**/*#{munged_tag}*"
  puts "Searching for files with glob #{glob}"
  files = Dir.glob(glob).select { |f| File.file?(f) }

  if platform && !platform.to_s.empty?
    parts = platform.split('-')
    os = parts[0].gsub('fedora', 'fc') + parts[1]
    files = files.select { |f| File.basename(f).include?(os) || File.basename(f).include?(platform) }
  end
  abort 'No files for the given tag found in the output directory.' if files.empty?

  s3_upload_files(files, tag)
end

# Transitional upload for the ezbake build output, removed once the vanagon
# pipeline is the only one
def ezbake_upload
  s3, bucket = s3_command_prefix

  config = File.expand_path('../target/staging/ezbake.rb', __dir__)
  abort "Could not find ezbake config from the build at #{config}" unless File.exist?(config)
  load config
  version = EZBake::Config.fetch(:version)
  release = EZBake::Config.fetch(:release)
  # If release is a digit, then we built a tagged version. Otherwise,
  # we built a snapshot and want to include that in the path to upload to.
  tag = release =~ /^\d{1,2}$/ ? version : "#{version}-#{release}"

  files = Dir.glob("#{__dir__}/../output/**/*#{tag}*")

  # Tarballs use a different version format than RPM/DEB packages.
  # ezbake generates the tarball name from the git tag (e.g. 8.13.0.SNAPSHOT.2026...)
  # while RPM/DEB use the version-release format (e.g. 8.13.0-0.1SNAPSHOT.2026...).
  # Pre-releases add a tilde suffix to the version here (e.g. 9.0.0~beta1) that the
  # git-tag tarball name lacks, so match on the base version to cover snapshots and
  # pre-releases alike.
  base_version = version.split('~').first
  tarball_files = Dir.glob("#{__dir__}/../output/openvox-server-#{base_version}*.tar.gz")
  files = (files + tarball_files).uniq

  abort 'No files for the given tag found in the output directory.' if files.empty?

  path = "s3://#{bucket}/openvox-server/#{tag}"
  files.each do |f|
    run_command("#{s3} cp #{f} #{path}/#{File.basename(f)} --no-progress", silent: false)
  end
end

namespace :vox do
  desc 'Upload built artifacts to S3. With tag and platform args this uploads the vanagon output, with no args it uploads the transitional ezbake output. Requires the AWS CLI to be installed and configured appropriately.'
  task :upload, [:tag, :platform] do |_, args|
    if args[:tag] && !args[:tag].to_s.empty?
      vanagon_upload(args[:tag], args[:platform])
    else
      ezbake_upload
    end
  end
end
