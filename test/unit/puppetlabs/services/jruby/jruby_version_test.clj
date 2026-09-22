(ns puppetlabs.services.jruby.jruby-version-test
  (:require [clojure.test :refer [deftest is testing]])
  (:import (org.jruby.runtime Constants)))

(deftest jruby-base-version-test
  (testing "the org.jruby/jruby-base dependency pulled in via jruby-utils -> jruby-deps is the expected version"
    (is (= "10.1.2.0" Constants/VERSION))))
