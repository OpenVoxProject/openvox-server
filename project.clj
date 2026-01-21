(def heap-size-from-profile-clj
  (let [profile-clj (io/file (System/getenv "HOME") ".lein" "profiles.clj")]
    (if (.exists profile-clj)
      (-> profile-clj
        slurp
        read-string
        (get-in [:user :puppetserver-heap-size])))))

(defn heap-size
  [default-heap-size]
  (or
    (System/getenv "PUPPETSERVER_HEAP_SIZE")
    heap-size-from-profile-clj
    default-heap-size))

(def slf4j-version "2.0.17")
(def i18n-version "1.0.3")
(def logback-version "1.3.16")
(def jackson-version "2.20.1")

(require '[clojure.string :as str]
         '[leiningen.core.main :as main])
(defn fail-if-logback->1-3!
  "Fails the build if logback-version is > 1.3.x."
  [logback-version]
  (let [[x y] (->> (str/split (str logback-version) #"\.")
                   (take 2)
                   (map #(Integer/parseInt %)))]
    (when (or (> x 1)
              (and (= x 1) (> y 3)))
      (main/abort (format "logback-version %s is not supported by Jetty 10. Must be 1.3.x until we update to Jetty 12." logback-version)))))

(fail-if-logback->1-3! logback-version)

;; If you modify the version manually, run scripts/sync_ezbake_dep.rb to keep
;; the ezbake dependency in sync.
(defproject org.openvoxproject/puppetserver "8.13.0-SNAPSHOT"
  :description "OpenVox Server"

  :license {:name "Apache License, Version 2.0"
              :url "http://www.apache.org/licenses/LICENSE-2.0.html"}

  :min-lein-version "2.9.1"

  ;; Generally, try to keep version pins in :managed-dependencies and the libraries
  ;; this project actually uses in :dependencies, inheriting the version from
  ;; :managed-dependencies. This prevents endless version conflicts due to deps of deps.
  ;; Renovate should keep the versions largely in sync between projects.
  :managed-dependencies [[org.clojure/clojure "1.12.4"]
                         [org.clojure/tools.namespace "0.3.1"]
                         [org.clojure/tools.reader "1.6.0"]
                         [beckon "0.1.1"]
                         [ch.qos.logback/logback-access ~logback-version]
                         [ch.qos.logback/logback-classic ~logback-version]
                         [ch.qos.logback/logback-core ~logback-version]
                         [cheshire "5.13.0"]
                         [clj-commons/fs "1.6.312"]
                         [clj-time "0.15.2"]
                         [com.fasterxml.jackson.core/jackson-core ~jackson-version]
                         [com.fasterxml.jackson.core/jackson-databind ~jackson-version]
                         [com.fasterxml.jackson.module/jackson-module-afterburner ~jackson-version]
                         ;; For some reason, this version is 2.20 without a .1. Update this back to
                         ;; ~jackson-version when they match again.
                         [com.fasterxml.jackson.core/jackson-annotations "2.20"]
                         [commons-codec "1.20.0"]
                         [commons-io "2.21.0"]
                         [grimradical/clj-semver "0.3.0" :exclusions [org.clojure/clojure]]
                         [io.dropwizard.metrics/metrics-core "3.2.6"]
                         [lambdaisland/uri "1.19.155"]
                         [liberator "0.15.3"]
                         [net.logstash.logback/logstash-logback-encoder "7.4"]
                         [org.apache.commons/commons-exec "1.6.0"]
                         [org.bouncycastle/bcpkix-jdk18on "1.83"]
                         [org.bouncycastle/bcpkix-fips "1.0.8"]
                         [org.bouncycastle/bc-fips "1.0.2.6"]
                         [org.bouncycastle/bctls-fips "1.0.19"]
                         [org.openvoxproject/clj-shell-utils "2.1.1"]
                         [org.openvoxproject/comidi "1.1.2"]
                         [org.openvoxproject/dujour-version-check "1.1.2"]
                         [org.openvoxproject/http-client "2.2.3"]
                         [org.openvoxproject/i18n ~i18n-version]
                         [org.openvoxproject/jruby-utils "5.3.6"]
                         [org.openvoxproject/kitchensink "3.5.5"]
                         [org.openvoxproject/kitchensink "3.5.5" :classifier "test"]
                         [org.openvoxproject/rbac-client "1.2.3"]
                         [org.openvoxproject/rbac-client "1.2.3" :classifier "test"]
                         [org.openvoxproject/ring-middleware "2.1.3"]
                         [org.openvoxproject/ssl-utils "3.6.2"]
                         [org.openvoxproject/trapperkeeper "4.3.2"]
                         [org.openvoxproject/trapperkeeper "4.3.2" :classifier "test"]
                         [org.openvoxproject/trapperkeeper-comidi-metrics "1.0.3"]
                         [org.openvoxproject/trapperkeeper-authorization "2.1.5"]
                         [org.openvoxproject/trapperkeeper-filesystem-watcher "1.5.1"]
                         [org.openvoxproject/trapperkeeper-metrics "2.1.6"]
                         [org.openvoxproject/trapperkeeper-metrics "2.1.6" :classifier "test"]
                         [org.openvoxproject/trapperkeeper-scheduler "1.3.1"]
                         [org.openvoxproject/trapperkeeper-status "1.3.1"]
                         [org.openvoxproject/trapperkeeper-webserver-jetty10 "1.1.3"]
                         [org.openvoxproject/trapperkeeper-webserver-jetty10 "1.1.3" :classifier "test"]
                         [org.ow2.asm/asm "9.9.1"]
                         [org.slf4j/jul-to-slf4j ~slf4j-version]
                         [org.slf4j/log4j-over-slf4j ~slf4j-version]
                         [org.slf4j/slf4j-api ~slf4j-version]
                         [org.yaml/snakeyaml "2.5"]
                         [pjstadig/humane-test-output "0.11.0"]
                         [prismatic/schema "1.4.1"]
                         [ring-basic-authentication "1.2.0"]
                         [ring/ring-codec "1.3.0"]
                         ;; DO NOT UPGRADE PAST 1.14+! In 1.15.x, Content-Length is added to the
                         ;; response headers automatically rather than transferring it chunked,
                         ;; and also string flushing behavior is changed, and some part of the system
                         ;; does not handle one or both of these correctly. We need to debug this and
                         ;; fix it before upgrading.
                         [ring/ring-core "1.14.2"]
                         [ring/ring-mock "0.6.2"]
                         [slingshot "0.12.2"]]

  :dependencies [[org.clojure/clojure]
                 [clj-commons/fs]
                 [clj-time]
                 [commons-io]
                 [grimradical/clj-semver :exclusions [org.clojure/clojure]]
                 [io.dropwizard.metrics/metrics-core]
                 [liberator]
                 ;; We do not currently use this dependency directly, but
                 ;; we have documentation that shows how users can use it to
                 ;; send their logs to logstash, so we include it in the jar.
                 [net.logstash.logback/logstash-logback-encoder]
                 [org.apache.commons/commons-exec]
                 [org.openvoxproject/clj-shell-utils]
                 [org.openvoxproject/comidi]
                 [org.openvoxproject/dujour-version-check]
                 [org.openvoxproject/http-client]
                 [org.openvoxproject/jruby-utils]
                 [org.openvoxproject/i18n]
                 [org.openvoxproject/kitchensink]
                 [org.openvoxproject/rbac-client]
                 [org.openvoxproject/ring-middleware]
                 [org.openvoxproject/ssl-utils]
                 [org.openvoxproject/trapperkeeper]
                 [org.openvoxproject/trapperkeeper-authorization]
                 [org.openvoxproject/trapperkeeper-comidi-metrics]
                 [org.openvoxproject/trapperkeeper-filesystem-watcher]
                 [org.openvoxproject/trapperkeeper-metrics]
                 [org.openvoxproject/trapperkeeper-scheduler]
                 [org.openvoxproject/trapperkeeper-status]
                 [org.openvoxproject/trapperkeeper-webserver-jetty10]
                 [org.yaml/snakeyaml]
                 [prismatic/schema]
                 [slingshot]]

  :main puppetlabs.trapperkeeper.main

  :pedantic? :abort

  :source-paths ["src/clj"]
  :java-source-paths ["src/java"]

  :test-paths ["test/unit" "test/integration"]
  :resource-paths ["resources" "src/ruby"]

  :deploy-repositories [["releases" {:url "https://clojars.org/repo"
                                     :username :env/CLOJARS_USERNAME
                                     :password :env/CLOJARS_PASSWORD
                                     :sign-releases false}]]

  :plugins [[jonase/eastwood "1.4.3" :exclusions [org.clojure/clojure]]
            ;; We have to have this, and it needs to agree with clj-parent
            ;; until/unless you can have managed plugin dependencies.
            [org.openvoxproject/i18n ~i18n-version :hooks false]
            [lein-shell "0.5.0"]]
  :uberjar-name "puppet-server-release.jar"
  :lein-ezbake {:vars {:user "puppet"
                       :group "puppet"
                       :numeric-uid-gid 52
                       :build-type "foss"
                       :package-name "openvox-server"
                       :puppet-platform-version 8
                       :java-args ~(str "-Xms2g -Xmx2g "
                                     "-Djruby.logger.class=com.puppetlabs.jruby_utils.jruby.Slf4jLogger")
                       :create-dirs ["/opt/puppetlabs/server/data/puppetserver/jars"
                                     "/opt/puppetlabs/server/data/puppetserver/yaml"]
                       :repo-target "openvox8"
                       :nonfinal-repo-target "openvox8-nightly"
                       :bootstrap-source :services-d
                       :logrotate-enabled false
                       :replaces-pkgs [{:package "puppetserver" :version ""}]}
                :resources {:dir "tmp/ezbake-resources"}
                :config-dir "ezbake/config"
                :system-config-dir "ezbake/system-config"}

  ;; By declaring a classifier here and a corresponding profile below we'll get an additional jar
  ;; during `lein jar` that has all the code in the test/ directory. Downstream projects can then
  ;; depend on this test jar using a :classifier in their :dependencies to reuse the test utility
  ;; code that we have.
  :classifiers [["test" :testutils]]

  :profiles {:defaults {:source-paths  ["dev"]
                        :dependencies  [[org.clojure/tools.namespace]
                                        [org.openvoxproject/trapperkeeper-webserver-jetty10 :classifier "test"]
                                        [org.openvoxproject/trapperkeeper :classifier "test" :scope "test"]
                                        [org.openvoxproject/trapperkeeper-metrics :classifier "test" :scope "test"]
                                        [org.openvoxproject/kitchensink :classifier "test" :scope "test"]
                                        [ring-basic-authentication]
                                        [ring/ring-mock]
                                        [beckon]
                                        [lambdaisland/uri]
                                        [org.openvoxproject/rbac-client :classifier "test" :scope "test"]]}
             :dev-deps {:dependencies [[org.bouncycastle/bcpkix-jdk18on]]}
             :dev [:defaults :dev-deps]
             :fips-deps {:dependencies [[org.bouncycastle/bcpkix-fips]
                                        [org.bouncycastle/bc-fips]
                                        [org.bouncycastle/bctls-fips]]
                         :lein-ezbake {:vars {:java-args ~(str
                                                            "-Djava.security.properties==/opt/puppetlabs/server/data/puppetserver/java.security.fips "
                                                            "-Xms2g -Xmx2g "
                                                            "-Djruby.logger.class=com.puppetlabs.jruby_utils.jruby.Slf4jLogger")}}
                         :jvm-opts ~(let [version (System/getProperty "java.specification.version")
                                          [major minor _] (clojure.string/split version #"\.")
                                          unsupported-ex (ex-info "Unsupported major Java version."
                                                           {:major major
                                                            :minor minor})]
                                      (condp = (java.lang.Integer/parseInt major)
                                        17 ["-Djava.security.properties==./resources/ext/build-scripts/java.security.fips"]
                                        21 ["-Djava.security.properties==./resources/ext/build-scripts/java.security.fips"]
                                        (do)))}
             :fips [:defaults :fips-deps]

             :testutils {:source-paths ["test/unit" "test/integration"]}
             :test {
                    ;; NOTE: In core.async version 0.2.382, the default size for
                    ;; the core.async dispatch thread pool was reduced from
                    ;; (42 + (2 * num-cpus)) to... eight.  The jruby metrics tests
                    ;; use core.async and need more than eight threads to run
                    ;; properly; this setting overrides the default value.  Without
                    ;; it the metrics tests will hang.
                    :jvm-opts ["-Dclojure.core.async.pool-size=50", "-Xms4g", "-Xmx4g"]
                    ;; Use humane test output so you can actually see what the problem is
                    ;; when a test fails.
                    :dependencies [[pjstadig/humane-test-output]]
                    :injections [(require 'pjstadig.humane-test-output)
                                 (pjstadig.humane-test-output/activate!)]}


             :ezbake {:dependencies ^:replace [;; we need to explicitly pull in our parent project's
                                               ;; clojure version here, because without it, lein
                                               ;; brings in its own version.
                                               ;; NOTE that these deps will completely replace the deps
                                               ;; in the list above, so any version overrides need to be
                                               ;; specified in both places. TODO: fix this.
                                               [org.clojure/clojure]
                                               [org.bouncycastle/bcpkix-jdk18on]
                                               [org.openvoxproject/jruby-utils]
                                               ;; Do not modify this line. It is managed by the release process
                                               ;; via the scripts/sync_ezbake_dep.rb script.
                                               [org.openvoxproject/puppetserver "8.13.0-SNAPSHOT"]
                                               [org.openvoxproject/trapperkeeper-webserver-jetty10]
                                               [org.openvoxproject/trapperkeeper-metrics]]
                      :plugins [[org.openvoxproject/lein-ezbake ~(or (System/getenv "EZBAKE_VERSION") "2.7.2")]]
                      :name "puppetserver"}

             :ezbake-fips {:dependencies ^:replace [[org.clojure/clojure]
                                                    [org.bouncycastle/bcpkix-jdk18on]
                                                    [org.openvoxproject/jruby-utils]
                                                    ;; Do not modify this line. It is managed by the release process
                                                    ;; via the scripts/sync_ezbake_dep.rb script.
                                                    [org.openvoxproject/puppetserver "8.13.0-SNAPSHOT"]
                                                    [org.openvoxproject/trapperkeeper-webserver-jetty10]
                                                    [org.openvoxproject/trapperkeeper-metrics]]
                            :uberjar-exclusions [#"^org/bouncycastle/.*"]
                            :plugins [[org.openvoxproject/lein-ezbake ~(or (System/getenv "EZBAKE_VERSION") "2.7.2")]]
                      :name "puppetserver"}
             :uberjar {:dependencies [[org.openvoxproject/trapperkeeper-webserver-jetty10]]
                       :aot [puppetlabs.trapperkeeper.main
                             puppetlabs.trapperkeeper.services.status.status-service
                             puppetlabs.trapperkeeper.services.metrics.metrics-service
                             puppetlabs.services.protocols.jruby-puppet
                             puppetlabs.trapperkeeper.services.watcher.filesystem-watch-service
                             puppetlabs.trapperkeeper.services.webserver.jetty10-service
                             puppetlabs.trapperkeeper.services.webrouting.webrouting-service
                             puppetlabs.services.legacy-routes.legacy-routes-core
                             puppetlabs.services.protocols.jruby-metrics
                             puppetlabs.services.protocols.ca
                             puppetlabs.puppetserver.common
                             puppetlabs.trapperkeeper.services.scheduler.scheduler-service
                             puppetlabs.services.jruby.jruby-metrics-core
                             puppetlabs.services.jruby.jruby-metrics-service
                             puppetlabs.services.protocols.puppet-server-config
                             puppetlabs.puppetserver.liberator-utils
                             puppetlabs.services.puppet-profiler.puppet-profiler-core
                             puppetlabs.services.jruby-pool-manager.jruby-pool-manager-service
                             puppetlabs.services.jruby.puppet-environments
                             puppetlabs.services.jruby.jruby-puppet-schemas
                             puppetlabs.services.jruby.jruby-puppet-core
                             puppetlabs.services.jruby.jruby-puppet-service
                             puppetlabs.puppetserver.jruby-request
                             puppetlabs.puppetserver.shell-utils
                             puppetlabs.puppetserver.ringutils
                             puppetlabs.puppetserver.certificate-authority
                             puppetlabs.services.ca.certificate-authority-core
                             puppetlabs.services.puppet-admin.puppet-admin-core
                             puppetlabs.services.puppet-admin.puppet-admin-service
                             puppetlabs.services.versioned-code-service.versioned-code-core
                             puppetlabs.services.ca.certificate-authority-disabled-service
                             puppetlabs.services.protocols.request-handler
                             puppetlabs.services.request-handler.request-handler-core
                             puppetlabs.puppetserver.cli.subcommand
                             puppetlabs.services.request-handler.request-handler-service
                             puppetlabs.services.protocols.versioned-code
                             puppetlabs.services.protocols.puppet-profiler
                             puppetlabs.services.puppet-profiler.puppet-profiler-service
                             puppetlabs.services.master.master-core
                             puppetlabs.services.protocols.master
                             puppetlabs.services.config.puppet-server-config-core
                             puppetlabs.services.config.puppet-server-config-service
                             puppetlabs.services.versioned-code-service.versioned-code-service
                             puppetlabs.services.legacy-routes.legacy-routes-service
                             puppetlabs.services.master.master-service
                             puppetlabs.services.ca.certificate-authority-service
                             puppetlabs.puppetserver.cli.ruby
                             puppetlabs.puppetserver.cli.irb
                             puppetlabs.puppetserver.cli.gem
                             puppetlabs.services.protocols.legacy-routes]}
             :ci {:plugins [[lein-pprint "1.3.2"]
                            [lein-exec "0.3.7"]]}}

  :test-selectors {:default (complement :multithreaded-only)
                   :integration :integration
                   :unit (complement :integration)
                   :multithreaded (complement :single-threaded-only)
                   :singlethreaded (complement :multithreaded-only)}

  :eastwood {:exclude-linters [:unused-meta-on-macro
                               :reflection
                               [:suspicious-test :second-arg-is-not-string]]
             :continue-on-exception true}

  :aliases {"gem" ["trampoline" "run" "-m" "puppetlabs.puppetserver.cli.gem" "--config" "./dev/puppetserver.conf" "--"]
            "ruby" ["trampoline" "run" "-m" "puppetlabs.puppetserver.cli.ruby" "--config" "./dev/puppetserver.conf" "--"]
            "irb" ["trampoline" "run" "-m" "puppetlabs.puppetserver.cli.irb" "--config" "./dev/puppetserver.conf" "--"]
            "thread-test" ["trampoline" "run" "-b" "ext/thread_test/bootstrap.cfg" "--config" "./ext/thread_test/puppetserver.conf"]}

  :jvm-opts ~(let [version (System/getProperty "java.specification.version")
                   [major minor _] (clojure.string/split version #"\.")]
               (concat
                 ["-Djruby.logger.class=com.puppetlabs.jruby_utils.jruby.Slf4jLogger"
                  "-XX:+UseG1GC"
                  (str "-Xms" (heap-size "1G"))
                  (str "-Xmx" (heap-size "2G"))
                  "-XX:+IgnoreUnrecognizedVMOptions"]
                 (if (>= 17 (java.lang.Integer/parseInt major))
                   ["--add-opens" "java.base/sun.nio.ch=ALL-UNNAMED" "--add-opens" "java.base/java.io=ALL-UNNAMED"]
                   [])))

  ;; We define our own release tasks here, rather than the default that 'lein release' does,
  ;; so that we can keep the necessary org.openvoxproject/puppetserver ezbake dependency in sync.
  ;; This also make is always bump the minor version rather than patch, since we rarely end up
  ;; releasing patch versions.
  :release-tasks [["vcs" "assert-committed"]
                  ["change" "version" "leiningen.release/bump-version" "release"]
                  ["shell" "ruby" "scripts/sync_ezbake_dep.rb"]
                  ["vcs" "commit"]
                  ["vcs" "tag"]
                  ["deploy"]
                  ["change" "version" "leiningen.release/bump-version" ":minor"]
                  ["shell" "ruby" "scripts/sync_ezbake_dep.rb"]
                  ["vcs" "commit"]
                  ["vcs" "push"]]

  :repl-options {:init-ns dev-tools}
  :uberjar-exclusions  [#"META-INF/jruby.home/lib/ruby/stdlib/org/bouncycastle"
                        #"META-INF/jruby.home/lib/ruby/stdlib/org/yaml/snakeyaml"]

  ;; This is used to merge the locales.clj of all the dependencies into a single
  ;; file inside the uberjar
  :uberjar-merge-with {"locales.clj"  [(comp read-string slurp)
                                       (fn [new prev]
                                         (if (map? prev) [new prev] (conj prev new)))
                                       #(spit %1 (pr-str %2))]})
