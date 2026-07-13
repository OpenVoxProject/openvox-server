(ns puppetlabs.services.master.master-service-readiness-test
  (:require [clojure.test :refer [deftest is testing]]
            [puppetlabs.comidi :as comidi]
            [puppetlabs.metrics.http :as http-metrics]
            [puppetlabs.puppetserver.certificate-authority :as ca]
            [puppetlabs.puppetserver.jruby-request :as jruby-request]
            [puppetlabs.services.master.master-core :as master-core]
            [puppetlabs.services.master.master-service :as master-service]
            [puppetlabs.trapperkeeper.app :as tk-app]
            [puppetlabs.trapperkeeper.core :refer [service]]
            [puppetlabs.trapperkeeper.internal :as tk-internal]
            [puppetlabs.trapperkeeper.services.status.status-core :as status-core]
            [puppetlabs.trapperkeeper.testutils.bootstrap :as tk-bootstrap-testutils]))

(defprotocol WebroutingService
  (get-route [this svc] [this svc route-id])
  (add-ring-handler [this svc handler] [this svc handler options]))

(defprotocol PuppetServerConfigService
  (get-config [this]))

(defprotocol RequestHandlerService
  (handle-request [this request]))

(defprotocol MetricsService
  (get-metrics-registry [this server-id])
  (get-server-id [this])
  (update-registry-settings [this server-id settings]))

(defprotocol CaService
  (initialize-master-ssl! [this settings certname])
  (retrieve-ca-cert! [this localcacert])
  (retrieve-ca-crl! [this hostcrl])
  (get-auth-handler [this]))

(defprotocol JRubyPuppetService)

(defprotocol AuthorizationService
  (wrap-with-authorization-check [this handler]))

(defprotocol StatusService
  (register-status [this service-name artifact-version service-version callback]))

(defprotocol VersionedCodeService
  (get-code-content [this environment code-id path])
  (current-code-id [this environment]))

(defprotocol JRubyMetricsService)

(def mock-config
  {:puppetserver {:certname "localhost"
                  :localcacert "target/test-ca.pem"
                  :hostcrl "target/test-crl.pem"
                  :puppet-version "9.0.0"}
   :jruby-puppet {:max-queued-requests 0
                  :environment-class-cache-enabled false}})

(def mock-services
  [(service WebroutingService
            []
            (get-route [_ _] nil)
            (get-route [_ _ _] nil)
            (add-ring-handler [_ _ _] nil)
            (add-ring-handler [_ _ _ _] nil))
   (service PuppetServerConfigService
            []
            (get-config [_] mock-config))
   (service RequestHandlerService
            []
            (handle-request [_ _] {:status 200 :body "ok"}))
   (service MetricsService
            []
            (get-metrics-registry [_ _] {})
            (get-server-id [_] "test-server")
            (update-registry-settings [_ _ _] nil))
   (service CaService
            []
            (initialize-master-ssl! [_ _ _] nil)
            (retrieve-ca-cert! [_ _] nil)
            (retrieve-ca-crl! [_ _] nil)
            (get-auth-handler [_] identity))
   (service JRubyPuppetService [])
   (service AuthorizationService
            []
            (wrap-with-authorization-check [_ handler] handler))
   (service StatusService
            []
            (register-status [_ _ _ _ _] nil))
   (service VersionedCodeService
            []
            (get-code-content [_ _ _ _] nil)
            (current-code-id [_ _] nil))
   (service JRubyMetricsService [])])

(deftest master-service-signals-readiness
  (testing "master-service registers and signals readiness during startup"
    (with-redefs [master-service/log-java-deprecation-message (fn [_] nil)
                  ca/config->master-settings (fn [_] {})
                  master-core/validate-memory-requirements! (fn [] nil)
                  master-core/get-master-route-config (fn [& _] {})
                  master-core/get-master-mount (fn [& _] "/puppet")
                  master-core/construct-root-routes (fn [& _] [])
                  master-core/register-jvm-metrics! (fn [& _] nil)
                  comidi/routes (fn [& _] nil)
                  comidi/context (fn [& _] nil)
                  comidi/route-metadata (fn [_] {})
                  comidi/routes->handler (fn [_] (fn [_] {:status 200 :body "ok"}))
                  comidi/wrap-with-route-metadata (fn [handler _] handler)
                  http-metrics/initialize-http-metrics! (fn [& _] {})
                  http-metrics/wrap-with-request-metrics (fn [handler _] handler)
                  jruby-request/wrap-with-request-queue-limit (fn [handler & _] handler)
                  status-core/get-artifact-version (fn [& _] "test-version")]
      (tk-bootstrap-testutils/with-app-with-config
       app
       (conj mock-services master-service/master-service)
       mock-config
       (let [readiness-service (tk-app/get-service app :ReadinessService)
             readiness-state (tk-internal/readiness-state readiness-service)]
         (is (contains? (:registered readiness-state) :MasterService))
         (is (contains? (:ready readiness-state) :MasterService))
         (is (true? (:notice-sent? readiness-state))))))))
