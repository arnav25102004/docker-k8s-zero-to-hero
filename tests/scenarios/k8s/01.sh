#!/usr/bin/env bash
# Spec for scenario K01 (01-excalidraw-pending). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-01-pending"
# pod_reason lives in the scenarios lib (the harness itself does not source it).
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(pod_reason k-01-pending app=draw)" "Pending" "draw Pod is Pending"
  assert_contains "$(kubectl get events -n k-01-pending 2>&1)" "Insufficient memory" "events say Insufficient memory"
}

fixed() {
  kubectl rollout status deployment/draw -n k-01-pending --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "draw Deployment rolled out"
  assert_eq "$(in_cluster_http_wait k-01-pending http://draw 200)" "200" "draw answers 200 inside the cluster"
}
