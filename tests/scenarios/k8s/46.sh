#!/usr/bin/env bash
# Spec for scenario K46 (46-the-3-am-page). Needs the monitoring stack (lab K19). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-46-3am"
CHECK46="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/46-the-3-am-page" && pwd)/check.sh"
ensure_monitoring || exit 1

ready46() { local r; r="$(kubectl get deployment orders -n k-46-3am -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }

check_passes46() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK46" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

broken() {
  assert_eq "$(ready46)" "0" "the orders Pod is never Ready"
  assert_contains "$(kubectl logs -n k-46-3am -l app=orders --previous 2>&1)" "no database called orders-bd" "the previous run's log names the bad database"
  prom_wait 'ALERTS{alertname="OrdersRestartingTooOften",alertstate="firing"}' 300
  assert_eq "$?" "0" "Prometheus fires the OrdersRestartingTooOften alert"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK46"
}

fixed() {
  kubectl rollout status deployment/orders -n k-46-3am --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "orders Deployment rolled out"
  check_passes46
  assert_eq "$?" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-46-3am http://orders 200)" "200" "orders answers 200 inside the cluster"
}
