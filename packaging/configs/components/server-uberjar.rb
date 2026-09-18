require_relative '../../lib/server_packaging'

# Prints the jars on the lein classpath for the given profiles, one per line
def classpath_jars(profiles)
  "$$LEIN with-profile #{profiles} classpath | tail -1 | tr ':' '\\n'"
end

# Copies one jar out of a saved classpath listing. The jar versions are only
# known inside the build container once lein has resolved them, so the lookup
# happens there. An absent jar makes cp fail on the empty path.
def copy_jar(jar, listing, destination)
  "cp \"$$(grep -E '/#{jar}-[0-9][^/]*\\.jar$$' #{listing})\" #{destination}/"
end

# Builds the puppetserver uberjar with leiningen and installs the vendored
# gems with the jar's own gem CLI. On FIPS, the jar is built without BouncyCastle
# embedded in the uberjar and the BC FIPS jars are installed next to it for the
# service to load at runtime.
component 'server-uberjar' do |pkg, settings, platform|
  pkg.version settings[:package_version]
  pkg.build_requires settings[:build_jdk]

  lein_version = settings[:lein_version]
  pkg.add_source "https://raw.githubusercontent.com/technomancy/leiningen/#{lein_version}/bin/lein",
                 sum: settings[:lein_script_sha256], sum_type: 'sha256'
  pkg.add_source "https://github.com/technomancy/leiningen/releases/download/#{lein_version}/leiningen-#{lein_version}-standalone.jar",
                 sum: settings[:lein_jar_sha256], sum_type: 'sha256'

  # The parts of the repo the uberjar build reads. With no primary source, the
  # build runs in the workdir root, where these land next to lein.
  %w[project.clj src resources].each { |path| pkg.add_source "file://../#{path}" }

  # Each build and install recipe is one shell, so lein is set up at the top of both
  lein_setup = "export LEIN_JAR=$$PWD/leiningen-#{lein_version}-standalone.jar LEIN=$$PWD/lein && chmod 0755 lein"

  deps_to_build, dep_branch, rebuild_org = ServerPackaging.clojure_dep_rebuild
  pkg.build_requires 'git' unless deps_to_build.empty?

  pkg.build do
    commands = [lein_setup]
    deps_to_build.each do |lib|
      commands << "git clone --no-checkout https://github.com/#{rebuild_org}/#{lib} deps/#{lib}"
      commands << "git -C deps/#{lib} fetch origin #{dep_branch}"
      commands << "git -C deps/#{lib} checkout FETCH_HEAD"
      commands << "(cd deps/#{lib} && $$LEIN install)"
    end
    commands << "$$LEIN with-profile #{settings[:uberjar_profiles]} uberjar"
    commands
  end

  app_dir = '/opt/puppetlabs/server/apps/puppetserver'
  jars_dir = '/opt/puppetlabs/server/data/puppetserver/jars'

  pkg.install do
    commands = [
      lein_setup,
      "install -m 0644 target/puppet-server-release.jar #{app_dir}/puppet-server-release.jar",
      # The gem install script runs the jar from the working directory
      'cp target/puppet-server-release.jar puppet-server-release.jar',
    ]

    if platform.is_fips?
      # JRuby's gem install needs the regular BC jars, which the FIPS jar leaves out.
      # This may change with JRuby's newer jruby-openssl that is FIPS-aware. If so,
      # remove this workaround and let it use the BC FIPS jars instead.
      commands << 'mkdir -p ext/classpath-jars'
      commands << "#{classpath_jars('user,pkg,provided')} > gem-classpath.txt"
      %w[bcpkix-jdk18on bcprov-jdk18on].each do |jar|
        commands << copy_jar(jar, 'gem-classpath.txt', 'ext/classpath-jars')
      end
    end

    commands << 'DESTDIR= bash resources/ext/build-scripts/install-vendored-gems.sh'

    if platform.is_fips?
      commands << "install -d #{jars_dir}"
      commands << "#{classpath_jars('user,fips-deps,provided')} > fips-classpath.txt"
      %w[bc-fips bcpkix-fips bctls-fips].each do |jar|
        commands << copy_jar(jar, 'fips-classpath.txt', jars_dir)
      end
    end

    commands
  end
end
