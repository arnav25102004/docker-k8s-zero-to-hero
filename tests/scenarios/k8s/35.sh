#!/usr/bin/env bash
# Spec for scenario K35 (35-biryani-that-needs-20-seconds). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-35-slow-biryani"
CHECK35="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/5-scaling-self-healing-and-releases/exercises/2-biryani-that-needs-20-seconds" && pwd)/check.sh"

restarts35() { kubectl get pods -n k-35-slow-biryani -l app=biryani -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
events35() { kubectl get events -n k-35-slow-biryani -o jsonpath='{.items[*].message}' 2>&1; }

# check.sh watches for 12 s itself, so give it a few tries
check_passes35() {
  local i
  export Z2H_CHECK_WATCH=5   # the learner's check.sh watches 12 s; the harness retries, so 5 s is enough
  for i in 1 2 3 4 5 6 7 8; do
    bash "$CHECK35" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

broken() {
  local i
  for i in $(seq 1 60); do
    [ "$(restarts35)" -ge 1 ] && break
    sleep 2
  done
  assert_eq "$([ "$(restarts35)" -ge 1 ] && echo yes || echo no)" "yes" "the Pods are being restarted (RESTARTS goes up)"
  assert_contains "$(events35)" "Liveness probe failed" "the events say the liveness probe failed"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK35"
}

fixed() {
  kubectl rollout status deployment/biryani -n k-35-slow-biryani --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "biryani Deployment rolled out"
  check_passes35
  assert_eq "$?" "0" "check.sh says: Ready and stable"
  assert_eq "$(in_cluster_http_wait k-35-slow-biryani http://biryani 200)" "200" "biryani answers 200 inside the cluster"
}
