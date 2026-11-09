#!/usr/bin/env bash
# Spec for scenario K22 (22-notice-board-readonly-fs). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-22-readonly-fs"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(pod_reason k-22-readonly-fs app=board)" "CrashLoopBackOff" "board Pod is CrashLoopBackOff"
  local prev
  prev="$(kubectl logs -n k-22-readonly-fs -l app=board --previous --tail=20 2>&1)"
  assert_contains "$prev" "Read-only file system" "previous logs say Read-only file system"
}

fixed() {
  kubectl rollout status deployment/board -n k-22-readonly-fs --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "board Deployment rolled out"
  assert_eq "$(in_cluster_http k-22-readonly-fs http://board)" "200" "board answers 200 inside the cluster"
}
