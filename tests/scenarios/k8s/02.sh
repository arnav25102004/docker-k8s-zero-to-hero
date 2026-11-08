#!/usr/bin/env bash
# Spec for scenario K02 (02-image-typo). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-02-image-typo"
# pod_reason lives in the scenarios lib (the harness itself does not source it).
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  local reason
  reason="$(pod_reason k-02-image-typo app=draw)"
  case "$reason" in
    ErrImagePull | ImagePullBackOff) assert_eq "ok" "ok" "draw Pod is stuck pulling its image ($reason)" ;;
    *) assert_eq "$reason" "ErrImagePull or ImagePullBackOff" "draw Pod is stuck pulling its image" ;;
  esac
  assert_contains "$(kubectl get events -n k-02-image-typo 2>&1)" "pull" "events mention the pull"
}

fixed() {
  kubectl rollout status deployment/draw -n k-02-image-typo --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "draw Deployment rolled out"
  assert_eq "$(in_cluster_http k-02-image-typo http://draw)" "200" "draw answers 200 inside the cluster"
}
