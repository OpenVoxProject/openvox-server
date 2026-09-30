# frozen_string_literal: true

require 'json'

# Smoke test for the packages that vox:build leaves in output. It installs the
# package for one vanagon build target, such as el-9-x86_64, in a container
# that runs systemd, starts the service, and runs the agent against it. The
# container is the image the vanagon platform defaults name for that target,
# on that target's architecture. The FIPS packages run on a regular kernel
# here, which covers install and startup.

# DOCKER_BIN swaps in another container engine, the same as for vox:build
SMOKE_DOCKER = ENV.fetch('DOCKER_BIN', 'docker').split.freeze
SMOKE_CONTAINER = 'openvox-server-smoke'
# The agent is installed from this repository
SMOKE_COLLECTION = 'openvox9'
# The server and the agent both take their certname from the hostname of the container
SMOKE_HOSTNAME = 'smoke.example.com'
# The architectures GitHub has runners for, as vanagon spells them
SMOKE_ARCHES = %w[amd64 x86_64 aarch64].freeze

# Runs docker without a shell in between, so the arguments need no quoting
def smoke_docker(*args)
  command = [*SMOKE_DOCKER, *args]
  puts "#{GREEN}Running #{command.join(' ')}#{RESET}"
  abort "#{RED}Command failed! Command: #{command.join(' ')}#{RESET}" unless system(*command)
end

def smoke_exec(script)
  smoke_docker('exec', SMOKE_CONTAINER, '/bin/bash', '-c', script)
end

# The container installs systemd before it hands over to it, so this can take a while
def smoke_wait_for_systemd
  puts "Waiting for systemd in #{SMOKE_CONTAINER}"
  state = nil
  60.times do
    state, = Open3.capture2e(*SMOKE_DOCKER, 'exec', SMOKE_CONTAINER, 'systemctl', 'is-system-running')
    # systemd reports degraded when a unit failed, which some do in a container. The state is
    # matched as a line because the container engine may print warnings of its own around it.
    return if state.match?(/^(running|degraded)$/)

    sleep 5
  end
  abort "#{RED}systemd did not come up in #{SMOKE_CONTAINER}, last state: #{state.strip}#{RESET}"
end

# The vanagon platform defaults name the image and the docker platform of every build
# target. The gem sits in the packaging group, so it is only loaded when a task needs it.
def smoke_vanagon_defaults
  require 'vanagon/platform'
  File.join(Gem.loaded_specs['vanagon'].gem_dir, 'lib', 'vanagon', 'platform', 'defaults')
end

namespace :vox do
  desc 'Smoke test the package in output for one vanagon target, for example vox:smoke[el-9-x86_64]'
  task :smoke, [:target] do |_, args|
    name = args[:target]
    abort 'You must provide a target, for example el-9-x86_64' if name.nil?
    defaults = smoke_vanagon_defaults
    target = Vanagon::Platform.load_platform(name, defaults)
    # The platform is the target without its architecture
    platform = name.sub(/-[^-]+$/, '')

    # Package file names have the platform without the dash, such as el9 or ubuntu24.04
    dist = platform.delete('-')
    packages = Dir.glob("output/**/*#{dist}*.{rpm,deb}")
    abort "Expected one #{platform} package in output, found #{packages.inspect}" unless packages.one?
    # The output directory is mounted at /output in the container
    package = "/#{packages.first}"

    release = "#{SMOKE_COLLECTION}-release"
    case platform
    when /^(debian|ubuntu)/
      # Keeps the configuration of packages from asking questions
      install = 'DEBIAN_FRONTEND=noninteractive apt-get install -y'
      # systemd alone is enough here, the services it recommends are meant for full hosts
      install_systemd = "apt-get update && #{install} --no-install-recommends systemd"
      install_release = "#{install} ca-certificates curl && " \
                        "curl -fsSL -o /tmp/#{release}.deb https://apt.voxpupuli.org/#{release}-#{dist}.deb && " \
                        "#{install} /tmp/#{release}.deb && apt-get update"
    when /^sles/
      # zypper has to import the key of the repository without asking and to accept the unsigned package in output
      install = 'zypper --non-interactive --gpg-auto-import-keys install --allow-unsigned-rpm'
      install_systemd = "#{install} systemd"
      # zypper cannot check the release package, because the key it is signed with only arrives with that package
      install_release = 'zypper --non-interactive --no-gpg-checks install ' \
                        "https://yum.voxpupuli.org/#{release}-#{platform}.noarch.rpm"
    else
      install = 'dnf install -y'
      install_systemd = "#{install} systemd"
      install_release = "#{install} https://yum.voxpupuli.org/#{release}-#{platform}.noarch.rpm"
    end

    begin
      # systemd reads the container variable to detect that it runs in a container
      smoke_docker('run', '--detach', '--name', SMOKE_CONTAINER, '--hostname', SMOKE_HOSTNAME,
                   '--platform', target.docker_arch, '--privileged', '--env', 'container=docker',
                   '--volume', "#{File.expand_path('output')}:/output:ro",
                   "#{target.docker_registry}/#{target.docker_image}",
                   '/bin/sh', '-c', "#{install_systemd} && exec /usr/lib/systemd/systemd")
      smoke_wait_for_systemd
      smoke_exec(install_release)
      smoke_exec("#{install} openvox-agent")
      smoke_exec("#{install} #{package}")
      # The unit is of type notify, so this returns once the server reports that it is ready
      smoke_exec('systemctl start puppetserver')
      smoke_exec("/opt/puppetlabs/bin/puppet agent --test --server #{SMOKE_HOSTNAME}")
      puts "#{GREEN}The #{platform} package passed the smoke test on #{name}#{RESET}"
    rescue SystemExit
      # Show what the container and the service logged before the container is removed
      system(*SMOKE_DOCKER, 'logs', SMOKE_CONTAINER)
      system(*SMOKE_DOCKER, 'exec', SMOKE_CONTAINER, 'journalctl', '--no-pager', '--unit', 'puppetserver')
      system(*SMOKE_DOCKER, 'exec', SMOKE_CONTAINER, 'cat', '/var/log/puppetlabs/puppetserver/puppetserver.log')
      raise
    ensure
      smoke_docker('rm', '--force', SMOKE_CONTAINER)
    end
  end

  namespace :smoke do
    desc 'List the vanagon targets to smoke test the packages in output on, as JSON'
    task :targets do
      # el-9 from output/el/9 and ubuntu-24.04 from output/deb/ubuntu24.04
      platforms = Dir.glob('output/**/*.{rpm,deb}').map do |package|
        os, version = package.split('/')[1, 2]
        os == 'deb' ? version.sub(/(\d)/, '-\1') : "#{os}-#{version}"
      end
      defaults = smoke_vanagon_defaults
      targets = platforms.uniq.sort.flat_map do |platform|
        # Only the architectures vanagon has a target for
        SMOKE_ARCHES.map { |arch| "#{platform}-#{arch}" }.select { |name| File.exist?(File.join(defaults, "#{name}.rb")) }
      end
      puts JSON.generate(targets)
    end
  end
end
