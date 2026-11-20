(ns puppetlabs.services.jruby.eyaml-decrypt-test
  (:require [clojure.java.shell :as shell]
            [clojure.test :refer [deftest is testing]]
            [puppetlabs.kitchensink.core :as ks]
            [puppetlabs.services.jruby.jruby-puppet-testutils :as jruby-testutils]
            [puppetlabs.trapperkeeper.app :as tk-app]
            [puppetlabs.trapperkeeper.testutils.bootstrap :as tk-bootstrap])
  (:import (com.puppetlabs.ssl_utils SSLUtils)))

(def encrypt-script
  "./dev-resources/puppetlabs/services/jruby/eyaml_decrypt_test/encrypt.rb")

(def decrypt-script
  "./dev-resources/puppetlabs/services/jruby/eyaml_decrypt_test/decrypt.rb")

(def plaintext "openvox eyaml secret")

(deftest ^:integration server-jruby-decrypts-eyaml-ciphertext-from-mri-test
  (let [directory (.getAbsolutePath (ks/temp-dir))
        ;; The ruby on PATH is MRI, which encrypts as it does on an agent
        {:keys [exit out err]} (shell/sh "ruby" encrypt-script directory plaintext)]
    (is (zero? exit)
        (str "ruby " encrypt-script " failed with exit code " exit ": " err out))
    (when (zero? exit)
      (tk-bootstrap/with-app-with-config
        app
        jruby-testutils/jruby-service-and-dependencies
        (jruby-testutils/jruby-puppet-tk-config
         (jruby-testutils/jruby-puppet-config
          {:server-code-dir (.getAbsolutePath (ks/temp-dir))
           :server-conf-dir (.getAbsolutePath (ks/temp-dir))
           :max-active-instances 1}))
        (let [jruby-service (tk-app/get-service app :JRubyPuppetService)
              instance (jruby-testutils/borrow-instance jruby-service :eyaml-decrypt-test)
              sc (:scripting-container instance)]
          (try
            (testing "Ruby's OpenSSL in a pooled JRuby decrypts the PKCS7 ciphertext that MRI made"
              (.runScriptlet sc (format "load '%s'" (ks/absolute-path decrypt-script)))
              (is (= plaintext (.runScriptlet sc (format "decrypt_eyaml('%s')" directory)))))

            (when (SSLUtils/isFIPS)
              (testing "the loaded jruby-openssl is the FIPS build"
                (is (= "fips" (.runScriptlet sc "Gem.loaded_specs['jruby-openssl'].metadata['jopenssl_variant']"))))
              (testing "OpenSSL is in FIPS mode"
                (is (= true (.runScriptlet sc "OpenSSL.fips_mode")))))
            (finally
              (jruby-testutils/return-instance jruby-service instance :eyaml-decrypt-test))))))))
