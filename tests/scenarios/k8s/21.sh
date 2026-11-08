#!/usr/bin/env bash
# Spec for scenario K21 (21-notice-board-runasnonroot). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-21-nonroot"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(pod_reason k-21-nonroot app=board)" "CreateContainerConfigError" "board Pod is CreateContainerConfigError"
  assert_contains "$(kubectl get events -n k-21-nonroot 2>&1)" "runAsNonRoot and image will run as root" "events say the image will run as root"
}

fixed() {
  kubectl rollout status deployment/board -n k-21-nonroot --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "board Deployment rolled out"
  assert_eq "$(in_cluster_http k-21-nonroot http://board)" "200" "board answers 200 inside the cluster"
}
