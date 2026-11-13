#!/usr/bin/env bash
# Spec for scenario K47 (47-the-deploy-nobody-could-place). Needs the monitoring stack (lab K19).
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-47-capacity"
CHECK47="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/47-the-deploy-nobody-could-place" && pwd)/check.sh"
ensure_monitoring || exit 1

ready47() { local r; r="$(kubectl get deployment checkout -n k-47-capacity -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }
events47() { kubectl get events -n k-47-capacity -o jsonpath='{.items[*].message}' 2>&1; }

check_passes47() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK47" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

broken() {
  assert_eq "$(ready47)" "0" "no checkout Pod is Ready"
  assert_contains "$(events47)" "Insufficient memory" "the scheduler says Insufficient memory"
  prom_wait 'ALERTS{alertname="CheckoutPodsPending",alertstate="firing"}' 300
  assert_eq "$?" "0" "Prometheus fires the CheckoutPodsPending alert"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK47"
}

fixed() {
  kubectl rollout status deployment/checkout -n k-47-capacity --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "checkout Deployment rolled out"
  check_passes47
  assert_eq "$?" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-47-capacity http://checkout 200)" "200" "checkout answers 200 inside the cluster"
}
