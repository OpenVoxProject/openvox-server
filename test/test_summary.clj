(ns test-summary
  (:require [clojure.string :as str]
            [clojure.test :as t]))

(def ^:private failures (atom []))

(defonce ^:private original-report-fail (get-method t/report :fail))
(defonce ^:private original-report-error (get-method t/report :error))
(defonce ^:private original-report-summary (get-method t/report :summary))

(defn- ns->path [ns]
  (-> (str ns)
      (str/replace "." "/")
      (str/replace "-" "_")
      (str ".clj")))

(defn- escape-message [s]
  (-> s
      (str/replace "%" "%25")
      (str/replace "\n" "%0A")
      (str/replace "\r" "%0D")))

(defmethod t/report :fail [m]
  (swap! failures conj (assoc m
                              :test-var (first t/*testing-vars*)
                              :contexts t/*testing-contexts*))
  (original-report-fail m))

(defmethod t/report :error [m]
  (swap! failures conj (assoc m
                              :test-var (first t/*testing-vars*)
                              :contexts t/*testing-contexts*))
  (original-report-error m))

(defmethod t/report :summary [m]
  (original-report-summary m)
  (when (seq @failures)
    (println "\n\n========== FAILURE SUMMARY ==========\n")
    (doseq [{:keys [type test-var message expected actual line]} @failures]
      (let [test-name (when test-var
                        (str (-> test-var meta :ns) "/" (-> test-var meta :name)))
            file-path (when test-var
                        (str "test/" (ns->path (-> test-var meta :ns))))
            error-message (str (name type) ": " test-name
                               "\n  expected: " (pr-str expected)
                               "\n    actual: " (pr-str actual)
                               (when message (str "\n  message: " message)))]
        (println (str "::error file=" file-path ",line=" line "::" (escape-message error-message)))))
    (println "\n======================================\n"))
  (reset! failures []))
