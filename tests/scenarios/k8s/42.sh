#!/usr/bin/env bash
# Spec for scenario K42 (42-who-gets-evicted-first). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-42-qos"
CHECK42="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/6-namespaces-quotas-helm-and-troubleshooting/exercises/2-who-gets-evicted-first" && pwd)/check.sh"

ready42() { local r; r="$(kubectl get deployment cache -n k-42-qos -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }
rsmsg42() { kubectl get rs -n k-42-qos -l app=cache -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>&1; }

qos42() { kubectl get pods -n k-42-qos -l app="$1" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].status.qosClass}' 2>/dev/null; }

broken() {
  assert_eq "$(qos42 cache)" "Burstable" "cache starts out Burstable (wrong)"
  assert_eq "$(qos42 web)" "Guaranteed" "web starts out Guaranteed (wrong)"
  assert_eq "$(qos42 batch)" "Burstable" "batch starts out Burstable (wrong)"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK42"
}

fixed() {
  local d
  for d in cache web batch; do
    kubectl rollout status deployment/$d -n k-42-qos --timeout=240s >/dev/null 2>&1
  done
  assert_eq "$(qos42 cache)" "Guaranteed" "cache is Guaranteed"
  assert_eq "$(qos42 web)" "Burstable" "web is Burstable"
  assert_eq "$(qos42 batch)" "BestEffort" "batch is BestEffort"
  assert_eq "$(bash "$CHECK42" >/dev/null 2>&1; echo $?)" "0" "check.sh says: done"
}
