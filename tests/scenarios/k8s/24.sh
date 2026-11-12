#!/usr/bin/env bash
# Spec for scenario K24 (24-showdown-wrong-command). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-24-never-ran"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

NS24="k-24-never-ran"

broken() {
  assert_contains "$(kubectl get events -n "$NS24" 2>&1)" "executable file not found" "events say the executable was not found"
  local restarts
  restarts=$(kubectl get pods -n "$NS24" -l app=showdown -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
  assert_eq "$([ "${restarts:-0}" -ge 1 ] && echo yes || echo no)" "yes" "the Pod has restarted at least once"
}

fixed() {
  kubectl rollout status deployment/showdown -n "$NS24" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(in_cluster_http_wait "$NS24" http://showdown/healthz 200)" "200" "showdown answers 200 inside the cluster"
}
