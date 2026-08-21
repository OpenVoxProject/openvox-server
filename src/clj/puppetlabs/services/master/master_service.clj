(ns puppetlabs.services.master.master-service
  (:require [clojure.tools.logging :as log]
            [clojure.walk :as walk]
            [puppetlabs.trapperkeeper.core :refer [defservice]]
            [puppetlabs.puppetserver.certificate-authority :as ca]
            [puppetlabs.puppetserver.jruby-request :as jruby-request]
            [puppetlabs.trapperkeeper.services :as tk-services]
            [puppetlabs.comidi :as comidi]
            [puppetlabs.metrics.http :as http-metrics]
            [puppetlabs.services.protocols.master :as master]
            [puppetlabs.i18n.core :as i18n]
            [puppetlabs.trapperkeeper.services.status.status-core :as status-core]
            [puppetlabs.services.master.master-core :as master-core]
            [clojure.string :as str]))

(def master-service-status-version 1)

;; Dropwizard 5 JMX rejects wildcard pattern characters in ObjectName values.
;; We replace route wildcards with a stable token before metrics registration.
(def metrics-route-wildcard-token "ANY")

(defn sanitize-metrics-route-id
  [route-id]
  (if (string? route-id)
    (str/replace route-id "*" metrics-route-wildcard-token)
    route-id))

(defn sanitize-route-metadata-for-metrics
  [route-metadata]
  (walk/postwalk
   (fn [node]
     (if (and (map? node) (string? (:route-id node)))
       (update node :route-id sanitize-metrics-route-id)
       node))
   route-metadata))

;; Default list of allowed histograms/timers
(def default-metrics-allowed-hists
  ["http.active-histo"
   "http.puppet-v3-catalog-/ANY/-requests"
   "http.puppet-v3-environment-/ANY/-requests"
   "http.puppet-v3-environment_classes-/ANY/-requests"
   "http.puppet-v3-environments-requests"
   "http.puppet-v3-file_bucket_file-/ANY/-requests"
   "http.puppet-v3-file_content-/ANY/-requests"
   "http.puppet-v3-file_metadata-/ANY/-requests"
   "http.puppet-v3-file_metadatas-/ANY/-requests"
   "http.puppet-v3-node-/ANY/-requests"
   "http.puppet-v3-report-/ANY/-requests"
   "http.puppet-v3-static_file_content-/ANY/-requests"])

;; Default list of allowed values/counts
(def default-metrics-allowed-vals
  ["http.active-requests"
   "http.puppet-v3-catalog-/ANY/-percentage"
   "http.puppet-v3-environment-/ANY/-percentage"
   "http.puppet-v3-environment_classes-/ANY/-percentage"
   "http.puppet-v3-environments-percentage"
   "http.puppet-v3-file_bucket_file-/ANY/-percentage"
   "http.puppet-v3-file_content-/ANY/-percentage"
   "http.puppet-v3-file_metadata-/ANY/-percentage"
   "http.puppet-v3-file_metadatas-/ANY/-percentage"
   "http.puppet-v3-node-/ANY/-percentage"
   "http.puppet-v3-report-/ANY/-percentage"
   "http.puppet-v3-static_file_content-/ANY/-percentage"
   "http.puppet-v3-status-/ANY/-percentage"
   "http.total-requests"
   ; num-cpus is registered in trapperkeeper-comidi-metrics, see
   ; https://github.com/puppetlabs/trapperkeeper-comidi-metrics/blob/0.1.1/src/puppetlabs/metrics/http.clj#L117-L120
   "num-cpus"])

;; List of allowed jvm gauges/values
(def default-jvm-metrics-allowed
  ["uptime"
   "memory.heap.committed"
   "memory.heap.init"
   "memory.heap.max"
   "memory.heap.used"
   "memory.non-heap.committed"
   "memory.non-heap.init"
   "memory.non-heap.max"
   "memory.non-heap.used"
   "memory.total.committed"
   "memory.total.init"
   "memory.total.max"
   "memory.total.used"])

(def http-client-metrics-allowed-hists
  (map #(format "http-client.experimental.with-metric-id.%s.full-response" (str/join "." %))
       master-core/puppet-server-http-client-metrics-for-status))

(def default-metrics-allowed
  (concat
   default-metrics-allowed-hists
   default-metrics-allowed-vals
   default-jvm-metrics-allowed
   http-client-metrics-allowed-hists))

(defn jdk-support-status
  "Returns :official, :deprecated, :unknown, or :unsupported."
  [version]
  (cond
    (re-matches #"1\.[1234567]($|(\..*))" version) :unsupported
    (re-matches #"1\.[89]($|(\..*))" version) :unsupported
    (re-matches #"10($|(\..*))" version) :unsupported
    (re-matches #"11($|(\..*))" version) :unsupported
    (re-matches #"17($|(\..*))" version) :unsupported
    (re-matches #"21($|(\..*))" version) :official
    (re-matches #"25($|(\..*))" version) :official
    :else :unknown))

(defn log-java-deprecation-message [version]
  (let [status (jdk-support-status version)]
    (case status
      (:unknown) (log/warn (i18n/trs "JDK {0} is neither tested nor supported. Please use JDK 21 or 25" version))
      (:deprecated) (log/warn (i18n/trs "JDK {0} is deprecated, please upgrade to JDK 21 or 25" version))
      (:official) nil
      (:unsupported) (log/warn (i18n/trs "Puppetserver doesn't support JDK {0}" version)))))

(defservice master-service
  master/MasterService
  [[:WebroutingService add-ring-handler get-route]
   [:PuppetServerConfigService get-config]
   [:RequestHandlerService handle-request]
   [:MetricsService get-metrics-registry get-server-id update-registry-settings]
   [:CaService initialize-master-ssl! retrieve-ca-cert! retrieve-ca-crl! get-auth-handler]
   [:JRubyPuppetService]
   [:AuthorizationService wrap-with-authorization-check]
   [:StatusService register-status]
   [:ReadinessService register-ready! signal-ready!]
   [:VersionedCodeService get-code-content current-code-id]]
  (init
   [this context]
   (register-ready! (tk-services/service-id this))
   (master-core/validate-memory-requirements!)
   (let [config (get-config)
         route-config (master-core/get-master-route-config ::master-service config)
         path (master-core/get-master-mount ::master-service route-config)
         certname (get-in config [:puppetserver :certname])
         localcacert (get-in config [:puppetserver :localcacert])
         puppet-version (get-in config [:puppetserver :puppet-version])
         max-queued-requests (get-in config [:jruby-puppet :max-queued-requests] 0)
         max-retry-delay (get-in config [:jruby-puppet :max-retry-delay] 1800)
         settings (ca/config->master-settings config)
         metrics-service (tk-services/get-service this :JRubyMetricsService)
         metrics-server-id (get-server-id)
         jruby-service (tk-services/get-service this :JRubyPuppetService)
         environment-class-cache-enabled (get-in config
                                                 [:jruby-puppet
                                                  :environment-class-cache-enabled]
                                                 false)
         wrap-with-jruby-queue-limit (if (pos? max-queued-requests)
                                       (fn [handler]
                                         (jruby-request/wrap-with-request-queue-limit
                                          handler
                                          metrics-service
                                          max-queued-requests
                                          max-retry-delay))
                                       identity)

         boltlib-path (get-in config [:jruby-puppet :boltlib-path])
         ring-app (comidi/routes
                   (master-core/construct-root-routes puppet-version
                                               jruby-service
                                               get-code-content
                                               current-code-id
                                               handle-request
                                               (get-auth-handler)
                                               wrap-with-jruby-queue-limit
                                               environment-class-cache-enabled
                                               boltlib-path
                                               certname))
         routes (comidi/context path ring-app)
         route-metadata (-> routes
                            comidi/route-metadata
                            sanitize-route-metadata-for-metrics)
         comidi-handler (comidi/routes->handler routes)
         registry (get-metrics-registry :puppetserver)
         http-metrics (http-metrics/initialize-http-metrics!
                       registry
                       metrics-server-id
                       route-metadata)
         http-client-metric-ids-for-status (atom master-core/puppet-server-http-client-metrics-for-status)
         ;; Middleware to sanitize live request route-ids so they match
         ;; the sanitized metric names registered during initialization.
         wrap-with-route-id-sanitization (fn [handler]
                                           (fn [req]
                                             (if (get-in req [:route-info :route-id])
                                               (handler (update-in req [:route-info :route-id] sanitize-metrics-route-id))
                                               (handler req))))
         ring-handler (-> comidi-handler
                          (http-metrics/wrap-with-request-metrics http-metrics)
                          wrap-with-route-id-sanitization
                          (comidi/wrap-with-route-metadata routes))
         hostcrl (get-in config [:puppetserver :hostcrl])]
     (log-java-deprecation-message (System/getProperty "java.version"))
     (retrieve-ca-cert! localcacert)
     (retrieve-ca-crl! hostcrl)
     (initialize-master-ssl! settings certname)

     (master-core/register-jvm-metrics! registry metrics-server-id)

     (update-registry-settings :puppetserver
                               {:default-metrics-allowed default-metrics-allowed})

     (log/info (i18n/trs "Master Service adding ring handlers"))

     ;; if the webrouting config uses the old-style config where
     ;; there is a single key with a route-id, we need to deal with that
     ;; for backward compat.  We have a hard-coded assumption that this route-id
     ;; must be `master-routes`.  In Puppet Server 2.0, we also supported a
     ;; key called `invalid-in-puppet-4` in the same route config, even though
     ;; that key is no longer used for Puppet Server 2.1 and later.  We
     ;; should be able to remove this hack as soon as we are able to get rid
     ;; of the legacy routes.
     (if (and (map? route-config)
              (contains? route-config :master-routes))
       (add-ring-handler this
                         ring-handler
                         {:route-id :master-routes
                          :normalize-request-uri true})
       (add-ring-handler this
                         ring-handler
                         {:normalize-request-uri true}))

     (register-status
      "master"
      (status-core/get-artifact-version "org.openvoxproject" "puppetserver")
      master-service-status-version
      (partial master-core/v1-status http-metrics http-client-metric-ids-for-status registry))
     (register-status
      "server"
      (status-core/get-artifact-version "org.openvoxproject" "puppetserver")
      master-service-status-version
      (partial master-core/v1-status http-metrics http-client-metric-ids-for-status registry))
     (-> context
         (assoc :http-metrics http-metrics)
         (assoc :http-client-metric-ids-for-status http-client-metric-ids-for-status))))
  (start
    [this context]
    (signal-ready! (tk-services/service-id this))
    (log/info (i18n/trs "OpenVox Server has successfully started and is now ready to handle requests"))
    context)

  (add-metric-ids-to-http-client-metrics-list!
   [this metric-ids-to-add]
   (let [metric-ids-from-context (:http-client-metric-ids-for-status
                                  (tk-services/service-context this))]
     (master-core/add-metric-ids-to-http-client-metrics-list! metric-ids-from-context
                                                              metric-ids-to-add))))
