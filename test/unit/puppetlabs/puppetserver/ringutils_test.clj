(ns puppetlabs.puppetserver.ringutils-test
  (:require [clojure.test :refer [deftest is testing use-fixtures]]
            [puppetlabs.puppetserver.ringutils :refer [wrap-with-cert-whitelist-check
                                                       wrap-with-puppet-version-header]]
            [puppetlabs.ssl-utils.core :as ssl-utils]
            [schema.test :as schema-test]))

(use-fixtures :once schema-test/validate-schemas)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Utilities

(def test-resources-dir
  "./dev-resources/puppetlabs/puppetserver/ringutils_test")

(defn test-pem-file
  [pem-file-name]
  (str test-resources-dir "/" pem-file-name))

(def localhost-cert
  (ssl-utils/pem->cert (test-pem-file "localhost-cert.pem")))

(def other-cert
  (ssl-utils/pem->cert (test-pem-file "revoked-agent.pem")))

(def base-handler
  (fn [_req]
    {:status 200 :body "hello"}))

(defn build-ring-handler
  [whitelist-settings]
  (-> base-handler
      (wrap-with-cert-whitelist-check whitelist-settings)))

(defn test-request
  [cert]
  {:uri "/foo"
   :request-method :get
   :ssl-client-cert cert})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Test

(deftest wrap-with-cert-whitelist-check-test
  (let [ring-handler (build-ring-handler
                       {:client-whitelist ["localhost"]})]
    (testing "access allowed when cert is on whitelist"
      (let [response (ring-handler (test-request localhost-cert))]
        (is (= 200 (:status response)))
        (is (= "hello" (:body response)))))
    (testing "access denied when cert not on whitelist"
      (let [response (ring-handler (test-request other-cert))]
        (is (= 403 (:status response))))))
  (let [ring-handler (build-ring-handler
                       {:authorization-required false
                        :client-whitelist       []})]
    (testing "access allowed when auth not required"
      (let [response (ring-handler (test-request other-cert))]
        (is (= 200 (:status response)))
        (is (= "hello" (:body response)))))))

(deftest wrap-with-puppet-version-header-test
  (testing "adds the X-Puppet-Version header when a version is supplied"
    (let [handler (wrap-with-puppet-version-header base-handler "1.2.3")
          response (handler (test-request localhost-cert))]
      (is (= "1.2.3" (get-in response [:headers "X-Puppet-Version"])))))
  (testing "omits the header when the version is blank (disable-version-header)"
    (let [handler (wrap-with-puppet-version-header base-handler "")
          response (handler (test-request localhost-cert))]
      (is (= 200 (:status response)))
      (is (nil? (get-in response [:headers "X-Puppet-Version"])))))
  (testing "strips a header set by a downstream handler when the version is blank"
    (let [downstream (fn [_req] {:status 200
                                 :headers {"X-Puppet-Version" "9.9.9"
                                           "Content-Type" "text/plain"}
                                 :body "hello"})
          handler (wrap-with-puppet-version-header downstream "")
          response (handler (test-request localhost-cert))]
      (is (= 200 (:status response)))
      (is (nil? (get-in response [:headers "X-Puppet-Version"])))
      (is (= "text/plain" (get-in response [:headers "Content-Type"])))))
  (testing "leaves nil responses untouched"
    (let [handler (wrap-with-puppet-version-header (constantly nil) "1.2.3")]
      (is (nil? (handler (test-request localhost-cert)))))))
