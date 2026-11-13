#!/usr/bin/env bash
# Spec for scenario K36 (36-two-probes-two-mistakes). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-36-two-probes"
CHECK36="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/5-scaling-self-healing-and-releases/exercises/3-two-probes-two-mistakes" && pwd)/check.sh"

restarts36() { kubectl get pods -n k-36-two-probes -l app=thali -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
events36() { kubectl get events -n k-36-two-probes -o jsonpath='{.items[*].message}' 2>&1; }
ready36() { local r; r="$(kubectl get deployment thali -n k-36-two-probes -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }

check_passes36() {
  local i
  export Z2H_CHECK_WATCH=5   # the learner's check.sh watches 12 s; the harness retries, so 5 s is enough
  for i in 1 2 3 4 5 6 7 8; do
    bash "$CHECK36" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

broken() {
  local i
  for i in $(seq 1 60); do
    [ "$(restarts36)" -ge 1 ] && break
    sleep 2
  done
  assert_eq "$([ "$(restarts36)" -ge 1 ] && echo yes || echo no)" "yes" "mistake 1: the Pods are restarted (liveness probe)"
  assert_eq "$(ready36)" "0" "mistake 2: no Pod is ever Ready (readiness probe)"
  assert_contains "$(events36)" "Liveness probe failed" "the events show liveness failing"
  assert_contains "$(events36)" "Readiness probe failed" "the events show readiness failing"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK36"
  # The boss claim: fixing only the liveness probe stops the restarts, but the stall stays closed.
  kubectl patch deployment thali -n k-36-two-probes --type json \
    -p '[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/port","value":8080}]' >/dev/null 2>&1
  sleep 30
  assert_eq "$(ready36)" "0" "after fixing only liveness, the stall is still closed (readiness still fails)"
}

fixed() {
  kubectl rollout status deployment/thali -n k-36-two-probes --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "thali Deployment rolled out"
  check_passes36
  assert_eq "$?" "0" "check.sh says: Ready and stable"
  assert_eq "$(in_cluster_http_wait k-36-two-probes http://thali 200)" "200" "thali answers 200 inside the cluster"
}
