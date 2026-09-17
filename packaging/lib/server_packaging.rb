# Naming and build knobs shared by the rake tasks and the vanagon configs, so
# the archive built by the openvox-server-uberjar project is found under the
# same name by the openvox-server project and by the local build helper.
module ServerPackaging
  # Platforms the uberjar project builds on. Both are AlmaLinux 9 images, which
  # carry the JDK 17 and JDK 21 packages, so one platform per variant serves
  # both release lines.
  UBERJAR_PLATFORMS = {
    'regular' => 'el-9-x86_64',
    'fips' => 'redhatfips-9-x86_64',
  }.freeze

  # The package build that also emits the source tarball downstream packagers
  # such as the FreeBSD port build from. Any one platform would do, this one is
  # in the platform lists of both release lines.
  SOURCE_TARBALL_PLATFORM = 'el-9-x86_64'

  # Clojure libraries that can be rebuilt from source before the uberjar
  # build, in dependency order. There is a circular dependency between
  # clj-http-client and trapperkeeper-webserver, but only for tests.
  CLOJURE_DEP_BUILD_ORDER = %w[
    clj-kitchensink
    clj-i18n
    comidi
    jvm-ssl-utils
    clj-typesafe-config
    jruby-deps
    trapperkeeper
    trapperkeeper-filesystem-watcher
    clj-http-client
    trapperkeeper-webserver
    ring-middleware
    jruby-utils
    clj-shell-utils
    trapperkeeper-authorization
    trapperkeeper-metrics
    trapperkeeper-scheduler
    trapperkeeper-status
    trapperkeeper-comidi-metrics
  ].freeze

  def self.uberjar_variant(platform_name)
    platform_name.start_with?('redhatfips') ? 'fips' : 'regular'
  end

  # Matches the archive name vanagon gives the uberjar project's output
  def self.uberjar_archive_name(version, variant)
    "openvox-server-uberjar-#{version}.#{UBERJAR_PLATFORMS.fetch(variant)}.tar.gz"
  end

  # The source tarball keeps the name ezbake gave it, and its top level
  # directory keeps the puppetserver name the FreeBSD port expects
  def self.source_tarball_name(version)
    "openvox-server-#{version}.tar.gz"
  end

  def self.source_tarball_root(version)
    "puppetserver-#{version}"
  end

  # Reads a dependency rebuild request from the environment. Returns the
  # libraries to build in order, the git ref to build them from, and the
  # GitHub organisation to clone them from.
  def self.clojure_dep_rebuild(env = ENV)
    org = env.fetch('DEP_REBUILD_ORG', 'openvoxproject')
    full_rebuild_branch = env['FULL_DEP_REBUILD_BRANCH'].to_s.strip
    return [CLOJURE_DEP_BUILD_ORDER, full_rebuild_branch, org] unless full_rebuild_branch.empty?

    subset = env['DEP_REBUILD'].to_s.split(',').map(&:strip).reject(&:empty?)
    return [[], nil, org] if subset.empty?

    unknown = subset - CLOJURE_DEP_BUILD_ORDER
    warn "WARNING: Unknown deps in DEP_REBUILD (will be ignored): #{unknown.join(', ')}" unless unknown.empty?
    [CLOJURE_DEP_BUILD_ORDER & subset, env.fetch('DEP_REBUILD_BRANCH', 'main'), org]
  end
end
