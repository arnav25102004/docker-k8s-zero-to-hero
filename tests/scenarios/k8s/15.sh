#!/usr/bin/env bash
# Spec for scenario K15 (15-stall-that-opens-one-at-a-time). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-15-statefulset"
CHECK15="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/15-stall-that-opens-one-at-a-time" && pwd)/check.sh"

pods15() { kubectl get pods -n k-15-statefulset -l app=stall --no-headers 2>/dev/null | wc -l | tr -d ' '; }
ready15() { local r; r="$(kubectl get statefulset stall -n k-15-statefulset -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }

check_passes15() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK15" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

broken() {
  sleep 8
  assert_eq "$(pods15)" "1" "only stall-0 exists: the other two are not even created"
  assert_eq "$(ready15)" "0" "no stall is Ready"
  assert_contains "$(kubectl get events -n k-15-statefulset -o jsonpath='{.items[*].message}' 2>&1)" "Readiness probe failed" "the events show the readiness probe failing"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK15"
}

fixed() {
  local i
  for i in $(seq 1 60); do [ "$(ready15)" = "3" ] && break; sleep 3; done
  assert_eq "$(ready15)" "3" "all three stalls are Ready"
  assert_eq "$(pods15)" "3" "exactly three Pods exist"
  check_passes15
  assert_eq "$?" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-15-statefulset http://stall 200)" "200" "the stall answers 200 inside the cluster"
}
