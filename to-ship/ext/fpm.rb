#!/usr/bin/env ruby

require 'open3'
require 'optparse'
require 'ostruct'

options = OpenStruct.new
# settin' some defaults
options.systemd = 0
options.sysvinit = 0
options.systemd_el = 0
options.systemd_sles = 0
options.old_el = 0
options.old_sles = 0
options.sles = 0
options.java = 'java-1.8.0-openjdk-headless'
options.release = 1
options.platform_version = 0
options.is_pe = false
options.replaces = {}
options.additional_dependencies = []
options.user = 'puppet'
options.group = 'puppet'
options.additional_dirs = []
options.sources = []
options.debug = false
options.logrotate = false
options.termini = false
options.termini_chdir = 'termini'
options.termini_sources = ['opt']
options.rpm_triggers = []
options.deb_interest_triggers = []
options.deb_activate_triggers = []
options.description = nil
options.termini_description = nil

OptionParser.new do |opts|
  opts.on('-o', '--operating-system OS', [:amazon, :fedora, :el, :redhatfips, :sles, :debian, :ubuntu], 'Select operating system (amazon, fedora, el, redhatfips, sles, debian, ubuntu)') do |o|
    options.operating_system = o
  end
  opts.on('--os-version VERSION', Integer, 'VERSION of the operating system to build for') do |v|
    options.os_version = v
  end
  opts.on('-n', '--name PROJECT', 'Name of the PROJECT to build') do |n|
    options.name = n
  end
  opts.on('--package-version VERSION', 'VERSION of the package to build') do |v|
    options.version = v
  end
  opts.on('--release RELEASE', 'RELEASE of the package') do |r|
    options.release = r
  end
  opts.on('--platform-version VERSION', Integer, 'VERSION of the puppet platform this builds for') do |v|
    options.platform_version = v
  end
  opts.on('--[no-]enterprise-build', 'Whether or not this is a PE build') do |e|
    options.is_pe = e
  end
  opts.on('--replaces <PKG,VERSION>', Array, 'PKG and VERSION replaced by this package. Can be passed multiple times.') do |pkg,ver|
    options.replaces[pkg] = ver
  end
  opts.on('--additional-dependency DEP', 'Additional dependency this package has. Can be passed multiple times.') do |dep|
    options.additional_dependencies << dep
  end
  opts.on('-u', '--user USER', 'USER that should be added with this package') do |user|
    options.user = user
  end
  opts.on('-g', '--group GROUP', 'GROUP that should be added with this package') do |group|
    options.group = group
  end
  opts.on('--create-dir DIR', 'The package should additionally create DIR') do |dir|
    options.additional_dirs << dir
  end
  opts.on('--realname NAME', 'The realname') do |name|
    options.realname = name
  end
  opts.on('--chdir DIR', 'The dir to chdir to before building') do |dir|
    options.chdir = dir
  end
  opts.on('--source <DIR>', Array, 'comma-separated list of source dirs') do |dir|
    options.sources = dir
  end
  opts.on('--dist NAME', 'the dist tag') do |dist|
    options.dist = dist
  end
  opts.on('--[no-]debug', 'for debugging purposes') do |d|
    options.debug = d
  end
  opts.on('--[no-]logrotate', 'to logrotate or not to logrotate') do |l|
    options.logrotate = l
  end
  opts.on('--[no-]build-termini', 'whether or not we should build a termini package') do |t|
    options.termini =  t
  end
  opts.on('--termini-chdir DIR', 'DIR for the termini build, defaults to "termini"') do |c|
    options.termini_chdir = c
  end
  opts.on('--termini-sources <SOURCES>', Array, 'sources for the termini build, defaults to "opt"') do |c|
    options.termini_chdir = c
  end
  opts.on('--rpm-trigger TRIGGER', 'TRIGGER for the rpm packages, in the format package:file_containing_script') do |t|
    options.rpm_triggers << t
  end
  opts.on('--deb-interest-trigger TRIGGER', 'name of the interest TRIGGER for the deb packages ') do |t|
    options.deb_interest_triggers << t
  end
  opts.on('--deb-activate-trigger TRIGGER', 'name of the activate TRIGGER for the deb packages') do |t|
    options.deb_activate_triggers << t
  end
  opts.on('--description DESCRIPTION', 'description for the package') do |d|
    options.description = d
  end
  opts.on('--termini-description DESCRIPTION', 'description for the termini package') do |d|
    options.termini_description = d
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

# validation
fail "--name is required!" unless options.name
options.realname = options.name if options.realname.nil?
fail "--package-version is required!" unless options.version
fail "--operating-system is required!" unless options.operating_system
options.chdir = options.dist if options.chdir.nil?
options.output_type = case options.operating_system
                      when :amazon, :fedora, :el, :sles, :redhatfips
                        'rpm'
                      when :debian, :ubuntu
                        'deb'
                      else
                        fail "Can't figure out the output type for #{options.operating_system}. Teach me?"
                      end
# don't require the os-version for deb, just require dist
fail "--os-version is required!" unless options.os_version or options.output_type == 'deb'
fail "--dist is required!" if options.output_type == 'deb' && options.dist.nil?
# set some default sources
if options.sources.empty?
  options.sources = case options.operating_system
                    when :amazon, :fedora, :sles, :el, :redhatfips
                      if options.operating_system == :el && options.os_version < 7 || options.operating_system == :sles && options.os_version < 12 #sysv rpm platforms
                        ['etc', 'opt', 'var']
                      else
                        ['etc', 'opt', 'usr', 'var']
                      end
                    when :debian, :ubuntu
                      if options.dist == 'trusty' #trusty is the only sysv deb we build for right now
                        ['etc', 'opt', 'var']
                      else
                        ['etc', 'lib', 'opt', 'usr', 'var']
                      end
                    else
                      fail "I don't know what your default sources should be, pass it on the command line!"
                    end
end
options.dist = "#{options.operating_system}#{options.os_version}" if options.dist.nil?

fpm_opts = Array('')
shared_opts = Array('')
termini_opts = Array('')

options.app_logdir = "/var/log/puppetlabs/#{options.realname}"
options.app_rundir = "/var/run/puppetlabs/#{options.realname}"
options.app_prefix = "/opt/puppetlabs/server/apps/#{options.realname}"
options.app_data = "/opt/puppetlabs/server/data/#{options.realname}"

# rpm specific options
if options.output_type == 'rpm'

  shared_opts << "--rpm-digest sha256"
  shared_opts << "--rpm-rpmbuild-define 'rpmversion #{options.version}'"
  fpm_opts << "--rpm-rpmbuild-define '_app_logdir #{options.app_logdir}'"
  fpm_opts << "--rpm-rpmbuild-define '_app_rundir #{options.app_rundir}'"
  fpm_opts << "--rpm-rpmbuild-define '_app_prefix #{options.app_prefix}'"
  fpm_opts << "--rpm-rpmbuild-define '_app_data #{options.app_data}'"

  if options.operating_system == :fedora # all supported fedoras are systemd
    options.systemd = 1
    options.systemd_el = 1
  elsif options.operating_system == :amazon
    fpm_opts << "--depends tzdata-java"
    options.java = '(java-17-amazon-corretto-headless or java-11-amazon-corretto-headless)'
    options.systemd = 1
    options.systemd_el = 1
  elsif options.operating_system == :el
    if options.os_version == 7
      options.java = 'jre-11-headless'
      options.java_bin = '/usr/lib/jvm/jre-11/bin/java'
    elsif (8..9).include?(options.os_version)
      options.java = 'jre-17-headless'
      options.java_bin = '/usr/lib/jvm/jre-17/bin/java'
    elsif options.os_version == 10
      options.java = 'jre-21-headless'
      options.java_bin = '/usr/lib/jvm/jre-21/bin/java'
    else
      fail "Unrecognized el os version #{options.os_version}"
    end

    options.systemd = 1
    options.systemd_el = 1
  elsif options.operating_system == :redhatfips && options.os_version >= 7 # systemd redhatfips
    options.systemd = 1
    options.systemd_el = 1
  elsif options.operating_system == :sles && options.os_version >= 12 # systemd sles
    options.systemd = 1
    options.systemd_sles = 1
    options.sles = 1
    if ! options.is_pe
      options.java = 'java-11-openjdk-headless'
    end
  elsif options.operating_system == :sles #old sles
    options.sysvinit = 1
    options.old_sles = 1
  end

  fpm_opts << "--rpm-rpmbuild-define '_with_sysvinit #{options.sysvinit}'"
  fpm_opts << "--rpm-rpmbuild-define '_with_systemd #{options.systemd}'"
  fpm_opts << "--rpm-rpmbuild-define '_old_sles #{options.old_sles}'"
  fpm_opts << "--rpm-rpmbuild-define '_systemd_el #{options.systemd_el}'"
  fpm_opts << "--rpm-rpmbuild-define '_systemd_sles #{options.systemd_sles}'"
  fpm_opts << "--rpm-rpmbuild-define '_old_el #{options.old_el}'"
  fpm_opts << "--rpm-rpmbuild-define '_sysconfdir /etc'"
  fpm_opts << "--rpm-rpmbuild-define '_prefix #{options.app_prefix}'"
  fpm_opts << "--rpm-rpmbuild-define '_rundir /var/run'"
  fpm_opts << "--rpm-rpmbuild-define '__jar_repack 0'"

  shared_opts << "--rpm-dist #{options.dist}"

  if options.old_el == 1
    fpm_opts << "--depends chkconfig"
  elsif options.old_sles == 1
    fpm_opts << "--depends aaa_base"
  end

  if options.systemd_el == 1
    fpm_opts << "--depends systemd"
  end

  if options.systemd_sles == 1
    fpm_opts << "--rpm-tag '%{?systemd_requires}'"
  end

  fpm_opts << "--config-files /etc/puppetlabs/#{options.realname}"
  fpm_opts << "--config-files /etc/sysconfig/#{options.realname}"

  options.additional_dirs.each do |dir|
    fpm_opts << "--directories #{dir}"
    fpm_opts << "--rpm-attr 700,#{options.user},#{options.group}:#{dir}"
  end

  options.rpm_triggers.each do |trigger|
    fpm_opts << "--rpm-trigger-after-install #{trigger}"
  end

  if options.logrotate
    fpm_opts << "--config-files /etc/logrotate.d/#{options.realname}"
  end

  fpm_opts << "--directories #{options.app_logdir}"
  fpm_opts << "--directories /etc/puppetlabs/#{options.realname}"
  fpm_opts << "--directories #{options.app_rundir}"
  shared_opts << "--rpm-auto-add-directories"
  fpm_opts << "--rpm-auto-add-exclude-directories /etc/puppetlabs"
  shared_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs"
  fpm_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/bin"
  fpm_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/server"
  fpm_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/server/apps"
  fpm_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/server/bin"
  fpm_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/server/data"
  fpm_opts << "--rpm-auto-add-exclude-directories /usr/lib/systemd"
  fpm_opts << "--rpm-auto-add-exclude-directories /usr/lib/systemd/system"
  fpm_opts << "--rpm-auto-add-exclude-directories /etc/init.d"
  fpm_opts << "--rpm-auto-add-exclude-directories /etc/rc.d"
  fpm_opts << "--rpm-auto-add-exclude-directories /etc/logrotate.d"
  fpm_opts << "--rpm-auto-add-exclude-directories /etc/rc.d/init.d"
  fpm_opts << "--rpm-auto-add-exclude-directories /usr/lib/tmpfiles.d"
  fpm_opts << "--rpm-auto-add-exclude-directories /var/log/puppetlabs"
  fpm_opts << "--rpm-auto-add-exclude-directories /var/run/puppetlabs"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/face"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/face/node"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/functions"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/indirector"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/indirector/catalog"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/indirector/facts"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/indirector/node"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/indirector/resource"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/reports"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/util"
  termini_opts << "--rpm-auto-add-exclude-directories /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/util/puppetdb"
  fpm_opts << "--rpm-attr 750,#{options.user},#{options.group}:/etc/puppetlabs/#{options.realname}"
  fpm_opts << "--rpm-attr 750,#{options.user},#{options.group}:#{options.app_logdir}"
  fpm_opts << "--rpm-attr -,#{options.user},#{options.group}:#{options.app_data}"
  fpm_opts << "--rpm-attr 755,#{options.user},#{options.group}:#{options.app_rundir}"

  fpm_opts << "--edit"
  fpm_opts << "--category 'System Environment/Daemons'"
  termini_opts << "--category 'Development/Libraries'"
#deb specific options
elsif options.output_type == 'deb'
  if options.dist != "#{options.operating_system}#{options.os_version}"
    options.release = "#{options.release}+#{options.dist}"
  end

  if ! options.is_pe
    options.java = 'openjdk-17-jre-headless | openjdk-11-jre-headless'
  end

  fpm_opts << '--deb-build-depends cdbs'
  fpm_opts << '--deb-build-depends bc'
  fpm_opts << '--deb-build-depends mawk'
  fpm_opts << '--deb-build-depends lsb-release'
  if options.is_pe
    fpm_opts << '--deb-build-depends puppet-agent'
  else
    fpm_opts << '--deb-build-depends "ruby | ruby-interpreter"'
  end
  fpm_opts << '--deb-priority optional'
  fpm_opts << '--category utils'
  options.deb_interest_triggers.each do |trigger|
    fpm_opts << "--deb-interest #{trigger}"
  end

   options.deb_activate_triggers.each do |trigger|
    fpm_opts << "--deb-activate #{trigger}"
  end
end

# generic options!
fpm_opts << "--name #{options.name}"
fpm_opts << "--description '#{options.description}'" unless options.description.nil?
termini_opts << "--name #{options.name}-termini"
termini_opts << "--description '#{options.termini_description}'" unless options.termini_description.nil?
shared_opts << "--version #{options.version}"
shared_opts << "--iteration #{options.release}"
shared_opts << "--vendor 'Vox Pupuli <openvox@voxpupuli.org>'"
shared_opts << "--maintainer 'Vox Pupuli <openvox@voxpupuli.org>'"
shared_opts << "--license 'ASL 2.0'"

shared_opts << "--url http://github.com/openvoxproject"
shared_opts << "--architecture all"

options.replaces.each do |pkg, version|
  # Strip the surrounding quotes since we add them in a certain way here.
  # We should probably just fix this in the core code by being smarter with
  # as-ruby-literaly, but someone more familiar with Clojure can do that part.
  pkg = pkg.delete_prefix("'").delete_suffix("'")
  version = version.delete_prefix("'").delete_suffix("'") unless version.nil?
  if options.output_type == 'rpm'
    val = if version.nil? || version.empty?
            "'#{pkg}'"
          else
            "'#{pkg} <= #{version}-1'"
          end
    fpm_opts << "--replaces #{val}"
    fpm_opts << "--conflicts #{val}"
  elsif options.output_type == 'deb'
    # why debian, why.
    if version.nil? || version.empty?
      fpm_opts << "--replaces '#{pkg}'"
      fpm_opts << "--conflicts '#{pkg}'"
    else
      fpm_opts << "--replaces '#{pkg} (<< #{version}-1voxpupuli1)'"
      fpm_opts << "--conflicts '#{pkg} (<< #{version}-1voxpupuli1)'"
      fpm_opts << "--replaces '#{pkg} (<< #{version}-1puppetlabs1)'"
      fpm_opts << "--conflicts '#{pkg} (<< #{version}-1puppetlabs1)'"
      fpm_opts << "--replaces '#{pkg} (<< #{version}-1#{options.dist})'"
      fpm_opts << "--conflicts '#{pkg} (<< #{version}-1#{options.dist})'"
    end
  end
end

# This is kludgy. Make it better one of these days for any package
# that has a corresponding termini package.
if options.name == "openvoxdb"
  termini_opts << "--replaces 'puppetdb-termini'"
  termini_opts << "--conflicts 'puppetdb-termini'"
end

if options.is_pe
  fpm_opts << "--depends pe-java"
  fpm_opts << "--depends pe-puppet-enterprise-release"
  fpm_opts << "--depends pe-bouncy-castle-jars"
else
  fpm_opts << "--depends '#{options.java}'"
end

fpm_opts << "--depends bash"
fpm_opts << "--depends net-tools"
fpm_opts << "--depends /usr/bin/which" if options.output_type == 'rpm'
fpm_opts << "--depends adduser" if options.output_type == 'deb'
fpm_opts << "--depends procps"

termini_opts << "--depends openvox-agent"

options.additional_dependencies.each do |dep|
  fpm_opts << "--depends '#{dep}'"
end

if options.output_type == 'rpm'
  script_dir = 'ext/redhat'
else
  script_dir = 'ext/debian'
end

fpm_opts << "--before-install #{script_dir}/preinst"
fpm_opts << "--after-install #{script_dir}/postinst"
fpm_opts << "--before-remove #{script_dir}/prerm"
fpm_opts << "--after-remove #{script_dir}/postrm"

fpm_opts << "--force"

shared_opts << "--output-type #{options.output_type}"
shared_opts << "--input-type dir"
fpm_opts << "--chdir #{options.chdir}"
termini_opts << "--chdir #{options.termini_chdir}"

fpm_opts << shared_opts
fpm_opts.flatten!

termini_opts << shared_opts
termini_opts.flatten!

fpm_opts << "#{options.sources.join(' ')}"
termini_opts << "#{options.termini_sources.join(' ')}"

# FPM prepends %dir to the %files list entries if the file is a directory
# https://github.com/jordansissel/fpm/blob/a996a8a404f012a4cdc95bce4b1e32b1982839e6/templates/rpm.erb#L249-L250
# This prevents us from recursively setting ownership/group on files within a directory
#
# There's a bit more we have to work around here. We want to recursively set owner
# and group for everything in the app data dir, but we also want to set the file
# mode for the data dir. Since FPM doesn't let us add multiple attributes for the
# same file, we're going to use the editor to add a second line in to the spec
# file setting up the mode for the top-level directory
#
# This sed command will take
#    %dir %attr(-, puppet, puppet) /opt/puppetlabs/server/data/app_name
#
# and convert it into
#    %attr(-, puppet, puppet) /opt/puppetlabs/server/data/app_name
#    %dir %attr (770, puppet, puppet) /opt/puppetlabs/server/data/app_name
#
# We should either open a issue/PR/etc to make this allowable in fpm, or we
# should refactor how we're building this package to explicitly set the root/root
# ownership for everything we need and set the default user/group attributes to
# be owned by the app user/group. But, in the interim we have this.
fpm_editor = 'FPM_EDITOR="sed -i \'s/%dir %attr(-\(.*\)/%attr(-\1\n%dir %attr(770\1/\'"'

if options.debug
  puts "=========================="
  puts "OPTIONS HASH"
  puts options
  puts "=========================="
  puts "=========================="
  puts "FPM COMMAND"
  puts "#{fpm_editor} fpm #{fpm_opts.join(' ')}"
  puts "=========================="
  puts "#{Dir.pwd}"
end

# fpm sends all output to stdout
out, _, stat = Open3.capture3("#{fpm_editor} fpm #{fpm_opts.join(' ')}")
fail "Error trying to run FPM for #{options.dist}!\n#{out}" unless stat.success?

puts "#{out}"

if options.termini
  if options.debug
    puts "=========================="
    puts "FPM COMMAND"
    puts "fpm #{termini_opts.join(' ')}"
    puts "=========================="
  end

  # fpm sends all output to stdout
  out, _, stat = Open3.capture3("fpm #{termini_opts.join(' ')}")
  fail "Error trying to run FPM for the termini for #{options.dist}!\n#{out}" unless stat.success?
  puts "#{out}"
end
