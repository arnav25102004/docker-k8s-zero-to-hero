#!/usr/bin/env bash
# Spec for scenario K10 (10-kanboard-pvc-pending). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-10-pvc-pending"

broken() {
  assert_eq "$(kubectl get pvc board-data -n k-10-pvc-pending -o jsonpath='{.status.phase}' 2>&1)" "Pending" "PVC board-data is Pending"
  assert_contains "$(kubectl get events -n k-10-pvc-pending 2>&1)" "fast-ssd" "events mention the missing StorageClass fast-ssd"
  assert_eq "$(kubectl get pod -n k-10-pvc-pending -l app=board -o jsonpath='{.items[0].status.phase}' 2>&1)" "Pending" "the board Pod is Pending"
}

fixed() {
  kubectl rollout status deployment/board -n k-10-pvc-pending --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "board Deployment rolled out (Ready 1/1)"
  assert_eq "$(kubectl get pvc board-data -n k-10-pvc-pending -o jsonpath='{.status.phase}' 2>&1)" "Bound" "PVC board-data is Bound"
  assert_eq "$(in_cluster_http k-10-pvc-pending http://board/healthcheck.php)" "200" "board answers 200 via the Service"
  local i seen=""
  for i in 1 2 3 4 5; do
    if kubectl logs visitor -n k-10-pvc-pending --tail=3 2>/dev/null | grep -q "✅"; then seen=yes; break; fi
    sleep 2
  done
  assert_eq "$seen" "yes" "visitor logs show ✅ within 10 s"
}
