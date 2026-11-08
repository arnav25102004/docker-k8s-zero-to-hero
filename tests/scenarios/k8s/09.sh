#!/usr/bin/env bash
# Spec for scenario K09 (09-adminer-missing-secret). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-09-missing-secret"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(pod_reason k-09-missing-secret app=adminer)" "CreateContainerConfigError" "the adminer Pod is stuck in CreateContainerConfigError"
  assert_contains "$(kubectl get events -n k-09-missing-secret 2>&1)" 'secret "adminer-db" not found' "events say secret \"adminer-db\" not found"
  assert_contains "$(kubectl logs -n k-09-missing-secret -l app=adminer 2>&1)" "CreateContainerConfigError" "there are no logs: the container never started"
}

fixed() {
  local i ready=""
  for i in $(seq 1 60); do
    ready="$(kubectl get pod -n k-09-missing-secret -l app=adminer -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)"
    [ "$ready" = "true" ] && break
    sleep 3
  done
  assert_eq "$ready" "true" "the adminer Pod is Ready (same Pod, started by the kubelet)"
  assert_eq "$(in_cluster_http k-09-missing-secret http://adminer)" "200" "adminer answers 200 via the Service"
  local seen=""
  for i in 1 2 3 4 5; do
    if kubectl logs visitor -n k-09-missing-secret --tail=3 2>/dev/null | grep -q "✅"; then seen=yes; break; fi
    sleep 2
  done
  assert_eq "$seen" "yes" "visitor logs show ✅ within 10 s"
}
