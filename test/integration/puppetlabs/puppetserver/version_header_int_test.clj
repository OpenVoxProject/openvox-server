(ns puppetlabs.puppetserver.version-header-int-test
  (:require
    [clojure.test :refer [deftest is testing use-fixtures]]
    [puppetlabs.trapperkeeper.testutils.logging :refer [with-test-logging]]
    [puppetlabs.puppetserver.bootstrap-testutils :as bootstrap]
    [puppetlabs.puppetserver.testutils :as testutils]
    [me.raynes.fs :as fs]))

(def test-resources
  "./dev-resources/puppetlabs/puppetserver/error_handling_int_test")

(use-fixtures :once
              (testutils/with-puppet-conf (fs/file test-resources "puppet.conf")))

(use-fixtures :each #(with-test-logging (%)))

;; The `certificate/ca` endpoint is served entirely by the Clojure CA layer and
;; is allow-unauthenticated, and the X-Puppet-Version header is added by the
;; Clojure middleware rather than JRuby, so mocking JRuby subverts no coverage.
(def ^:private mock-reason
  "X-Puppet-Version is added by the Clojure middleware, not JRuby; this test only
  exercises that layer via the unauthenticated CA certificate endpoint.")

;; Headers come back lower-cased from the HTTP client (see other int-tests that
;; look up "content-type"), so we look up "x-puppet-version".
(def ^:private version-header "x-puppet-version")

(deftest ^:integration expose-version-header-default-test
  (testing "X-Puppet-Version is present by default (expose-version-header unset)"
    (bootstrap/with-puppetserver-running-with-mock-jrubies
     mock-reason app {}
     (let [response (testutils/http-get "puppet-ca/v1/certificate/ca")]
       (is (= 200 (:status response)))
       (is (some? (get-in response [:headers version-header]))
           "the version header should be present by default")))))

(deftest ^:integration expose-version-header-disabled-test
  (testing "X-Puppet-Version is omitted when expose-version-header is false"
    (bootstrap/with-puppetserver-running-with-mock-jrubies
     mock-reason app {:expose-version-header false}
     (let [response (testutils/http-get "puppet-ca/v1/certificate/ca")]
       (is (= 200 (:status response)))
       (is (nil? (get-in response [:headers version-header]))
           "the version header should be stripped when expose-version-header is false")))))
