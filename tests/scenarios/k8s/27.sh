#!/usr/bin/env bash
# Spec for scenario K27 (27-upgrade-that-broke-the-stall). Needs helm. Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-27-helm"
CHECK27="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/6-namespaces-quotas-helm-and-troubleshooting/3-upgrade-that-broke-the-stall" && pwd)/check.sh"
command -v helm >/dev/null 2>&1 || { printf 'helm is needed for scenario K27\n' >&2; exit 1; }

img27() { kubectl get deployment stall -n k-27-helm -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null; }

check_passes27() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK27" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

broken() {
  assert_contains "$(img27)" "9.9.9" "the upgrade put a bad image tag in the Deployment"
  assert_contains "$(helm history stall -n k-27-helm 2>&1)" "deployed" "Helm reports the upgrade as deployed"
  assert_contains "$(kubectl get pods -n k-27-helm -l app=stall -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>&1)" "Image" "a new Pod cannot pull its image"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK27"
}

fixed() {
  kubectl rollout status deployment/stall -n k-27-helm --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "stall Deployment rolled out"
  assert_contains "$(img27)" "1.0.0" "the good image is back"
  assert_contains "$(helm history stall -n k-27-helm 2>&1)" "Rollback to 1" "Helm history records the rollback"
  check_passes27
  assert_eq "$?" "0" "check.sh says: done"
}
