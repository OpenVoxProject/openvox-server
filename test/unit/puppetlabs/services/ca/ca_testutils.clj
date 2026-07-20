(ns puppetlabs.services.ca.ca-testutils
   (:require [clojure.java.io :as io]
             [clojure.string :as str]
             [clojure.test :refer [is]]
             [me.raynes.fs :as fs]
             [puppetlabs.kitchensink.core :as ks]
             [puppetlabs.kitchensink.file :as ks-file]
             [puppetlabs.services.jruby.jruby-puppet-testutils :as jruby-testutils])
  (:import (java.io ByteArrayInputStream)
           (java.math BigInteger)
           (java.util.concurrent.locks ReentrantReadWriteLock)))

(defn assert-subject [o subject]
  (is (= subject (-> o .getSubjectX500Principal .getName))))

(defn assert-issuer [o issuer]
  (is (= issuer (-> o .getIssuerX500Principal .getName))))

(defn pem-to-stream
  [pem-string]
  (ByteArrayInputStream. (.getBytes (slurp pem-string))))

(defmacro with-backed-up-crl
  [crl-path crl-backup-path & body]
  `(do
     (fs/copy ~crl-path ~crl-backup-path)
     (try
       ~@body
       (finally
         (fs/delete ~crl-path)
         (fs/move ~crl-backup-path ~crl-path)))))

(defn master-settings
  "Master configuration settings with defaults appropriate for testing.
   All file and directory paths will be rooted at the provided `confdir`."
  ([confdir] (master-settings confdir "localhost"))
  ([confdir hostname]
     (let [ssldir (str confdir "/ssl")]
       {:certdir        (str ssldir "/certs")
        :dns-alt-names  ""
        :hostcert       (str ssldir "/certs/" hostname ".pem")
        :hostcrl        (str ssldir "/certs/crl.pem")
        :hostprivkey    (str ssldir "/private_keys/" hostname ".pem")
        :hostpubkey     (str ssldir "/public_keys/" hostname ".pem")
        :localcacert    (str ssldir "/certs/ca.pem")
        :privatekeydir (str ssldir "/private_keys")
        :requestdir     (str ssldir "/certificate_requests")
        :csr-attributes (str confdir "/csr_attributes.yaml")
        :keylength      512})))

(defn ca-settings
  "CA configuration settings with defaults appropriate for testing.
   All file and directory paths will be rooted at the static 'cadir'
   in dev-resources, unless a different `cadir` is provided."
  [cadir]
  {:access-control                   {:certificate-status {:client-whitelist ["localhost"]}}
   :autosign                         true
   :allow-authorization-extensions   false
   :allow-duplicate-certs            false
   :allow-subject-alt-names          false
   :allow-auto-renewal               false
   :auto-renewal-cert-ttl            "90d"
   :ca-name                          "test ca"
   :ca-ttl                           1
   :allow-header-cert-info           false
   :cadir                            (str cadir)
   :cacrl                            (str cadir "/ca_crl.pem")
   :cacert                           (str cadir "/ca_crt.pem")
   :cakey                            (str cadir "/ca_key.pem")
   :capub                            (str cadir "/ca_pub.pem")
   :cert-inventory                   (str cadir "/inventory.txt")
   :csrdir                           (str cadir "/requests")
   :keylength                        512
   :manage-internal-file-permissions true
   :signeddir                        (str cadir "/signed")
   :serial                           (str cadir "/serial")
   :infra-serial                     (str cadir "/infra_serial")
   :ruby-load-path                   jruby-testutils/ruby-load-path
   :gem-path                         jruby-testutils/gem-path
   :infra-nodes-path                 (str cadir "/infra_inventory.txt")
   :infra-node-serials-path          (str cadir "/infra_serials")
   :infra-crl-path                   (str cadir "/infra_crl.pem")
   :enable-infra-crl                 false
   :serial-lock                      (new ReentrantReadWriteLock)
   :serial-lock-timeout-seconds      5
   :crl-lock                         (new ReentrantReadWriteLock)
   :crl-lock-timeout-seconds         5
   :inventory-lock                   (new ReentrantReadWriteLock)
   :inventory-lock-timeout-seconds   5
   :serial-type                      :incrementing
   :infra-serial-type                :incrementing})

(defn uuid-ca-settings
  "CA configuration settings with UUID-based serial numbers for testing.
   See ca-settings for documentation."
  [cadir]
  (assoc (ca-settings cadir)
         :serial-type :uuid
         :infra-serial-type :uuid))

(defn infra-node-ca-settings
  "Create CA settings with infrastructure nodes pre-configured.

   Useful for testing infrastructure-specific serial number modes and
   node classification logic.

   Parameters:
     cadir - Directory for CA files
     infra-hostnames - Sequence of hostnames to classify as infrastructure
                      Example: [\"puppet\" \"puppetdb\"]

   Returns:
     CA settings map with:
     - infra-nodes-path pointing to temp file
     - File created and populated with hostnames
     - Other settings same as ca-settings()

   Examples:
     (infra-node-ca-settings (ks/temp-dir) [\"puppet\" \"puppetdb\"])
     ; => {:serial :path ..., :infra-nodes-path \"/tmp/xyz/infra_inventory.txt\", ...}"
  [cadir infra-hostnames]
  (let [settings (ca-settings cadir)
        infra-file (str cadir "/infra_inventory_test.txt")]
    (spit infra-file (str/join "\n" infra-hostnames))
    (assoc settings :infra-nodes-path infra-file)))

(defn mixed-mode-ca-settings
  "Create CA settings with different serial types for CA and infra nodes.

   Allows testing the interaction between different serial number modes
   on the same CA instance.

   Parameters:
     cadir - Directory for CA files
     ca-serial-type - Serial type for regular nodes
                     (:incrementing or :uuid)
     infra-serial-type - Serial type for infrastructure nodes
                        (:incrementing or :uuid)
     infra-hostnames - Optional list of infrastructure node names
                      Default: [\"puppet\"] if not provided

   Returns:
     CA settings map with:
     - :serial-type set to ca-serial-type
     - :infra-serial-type set to infra-serial-type
     - infra-nodes-path configured with hostnames

   Examples:
     ; CA uses incrementing, infra uses UUID
     (mixed-mode-ca-settings (ks/temp-dir) :incrementing :uuid)

     ; Both use UUID
     (mixed-mode-ca-settings (ks/temp-dir) :uuid :uuid)

     ; With custom infra nodes
     (mixed-mode-ca-settings (ks/temp-dir) :incrementing :uuid
                             [\"puppet\" \"puppetdb\" \"console\"])"
  ([cadir ca-serial-type infra-serial-type]
   (mixed-mode-ca-settings cadir ca-serial-type infra-serial-type ["puppet"]))
  ([cadir ca-serial-type infra-serial-type infra-hostnames]
   (let [settings (ca-settings cadir)
         infra-file (str cadir "/infra_inventory_test.txt")]
     (spit infra-file (str/join "\n" infra-hostnames))
     (-> settings
         (assoc :serial-type ca-serial-type)
         (assoc :infra-serial-type infra-serial-type)
         (assoc :infra-nodes-path infra-file)))))

(defn ca-sandbox!
  "Copy the `cadir` to a temporary directory and return
   the 'ca-settings' map rooted at the temporary directory.
   The directory will be deleted when the JVM exits."
  [cadir]
  (let [tmp-ssldir (ks/temp-dir)]
    (fs/copy-dir cadir tmp-ssldir)
    ;; This is to ensure no warnings are logged during tests
    (ks-file/set-perms (str tmp-ssldir "/ca/ca_key.pem") "rw-r-----")
    (ca-settings (str tmp-ssldir "/ca"))))

(defn assert-uuid-serial
  "Assert that a certificate serial is a valid UUID-based BigInteger.

   Verifies:
     1. Serial is BigInteger instance
     2. Serial is positive (> 0)
     3. Serial fits X.509 20-byte limit (bitLength <= 160)

   Parameters:
     cert - X509Certificate to validate
     message - Optional assertion message for failure case

   Examples:
     (assert-uuid-serial signed-cert)
     (assert-uuid-serial signed-cert \"Master cert should have UUID serial\")

   Implementation:
     - Uses clojure.test/is for assertions
     - Fails with clear message if constraints violated
     - Includes actual serial value in failure message"
  [cert & [message]]
  (let [serial (.getSerialNumber cert)]
    (is (instance? BigInteger serial)
        (or message "Serial must be BigInteger instance"))
    (is (pos? serial)
        (or message (str "Serial must be positive, got: " serial)))
    (is (<= (.bitLength serial) 160)
        (or message
            (str "Serial must fit X.509 limit (160 bits), got bitLength: "
                 (.bitLength serial))))))

(defn assert-incrementing-serial
  "Assert that a certificate serial is from incrementing mode.

   Verifies serial is within expected range for incrementing mode.
   Useful for confirming correct serial type was used.

   Parameters:
     cert - X509Certificate to validate
     expected-max - Maximum expected serial value
     message - Optional assertion message

   Examples:
     (assert-incrementing-serial signed-cert 100)
     (assert-incrementing-serial signed-cert 1000
                                  \"Agent serial should be < 1000\")"
  [cert expected-max & [message]]
  (let [serial (.getSerialNumber cert)]
    (is (instance? BigInteger serial))
    (is (pos? serial))
    (is (<= serial (biginteger expected-max))
        (or message
            (str "Serial " serial " exceeds max " expected-max)))))

(defn assert-serial-in-inventory
  "Assert that a certificate's serial is recorded in inventory file.

   Parameters:
     cert - X509Certificate
     inventory-path - Path to inventory file
     message - Optional assertion message

   Verifies:
     - Inventory entry exists for cert
     - Serial in inventory matches cert serial
     - Entry format is correct"
  [cert inventory-path & [message]]
  (let [serial (.getSerialNumber cert)
        ; Read inventory, parse entries, find matching entry
        entries (with-open [r (io/reader inventory-path)]
                  (line-seq r))
        serial-hex (.toString serial 16)]
    (is (some #(re-find (re-pattern (str "0x" serial-hex)) %) entries)
        (or message (str "Serial " serial " not found in inventory at " inventory-path)))))
