(ns puppetlabs.services.puppet-profiler.puppet-profiler-metrics-test
  (:require [clojure.test :refer [deftest testing is]])
  (:import (io.dropwizard.metrics5 MetricRegistry Timer)
           (com.puppetlabs.puppetserver MetricsPuppetProfiler)))

(deftest test-metrics-puppet-profiler-integration
  (testing "Metric name construction via start/finish using StringBuilder refactor"
    (let [registry (MetricRegistry.)
          hostname "localhost.test"
          profiler (MetricsPuppetProfiler. hostname registry)
          metric-id (into-array String ["compiler" "evaluate" "resource_types"])
          ctx (.start profiler "sample-event" metric-id)]
      (.finish profiler ctx "sample-event" metric-id)
      (testing "Registers hierarchical timer metrics with correct dotted names"
        (let [metrics-map (.getMetrics registry)
              registered-names (set (map str (.keySet metrics-map)))]
          (is (contains? registered-names "puppetlabs.localhost.test.compiler")
              "Should register the 1-segment prefix timer")
          (is (contains? registered-names "puppetlabs.localhost.test.compiler.evaluate")
              "Should register the 2-segment prefix timer")
          (is (contains? registered-names "puppetlabs.localhost.test.compiler.evaluate.resource_types")
              "Should register the full 3-segment timer")
          (doseq [n ["puppetlabs.localhost.test.compiler"
                     "puppetlabs.localhost.test.compiler.evaluate"
                     "puppetlabs.localhost.test.compiler.evaluate.resource_types"]]
            (let [metric-key (first (filter #(= (str %) n) (.keySet metrics-map)))]
              (is (instance? Timer (.get metrics-map metric-key))
                  (str n " should be a Timer instance"))))))
      (testing "List mutation isolation - successive calls don't accumulate prefixes"
        (let [second-metric-id (into-array String ["parser" "lexing"])
              ctx2 (.start profiler "second-event" second-metric-id)]
          (.finish profiler ctx2 "second-event" second-metric-id)
          (let [metrics-map (.getMetrics registry)
                registered-names (set (map str (.keySet metrics-map)))]
            (is (contains? registered-names "puppetlabs.localhost.test.parser.lexing")
                "Second independent metric should register correctly")
            (is (not (contains? registered-names "puppetlabs.localhost.test.compiler.evaluate.resource_types.parser.lexing"))
                "Metric IDs from separate profile events must not bleed into each other")
            (is (not (some #(re-find #"puppetlabs\.localhost\.test\.puppetlabs" %) registered-names))
                "The hostname prefix must not accumulate across repeated getMetricName calls")))))))
