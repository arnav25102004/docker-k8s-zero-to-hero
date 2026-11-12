#!/usr/bin/env bash
# Spec for scenario K06 (06-kanboard-never-ready). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-06-never-ready"

broken() {
  local phase ready
  phase="$(kubectl get pod -n k-06-never-ready -l app=board -o jsonpath='{.items[0].status.phase}' 2>&1)"
  assert_eq "$phase" "Running" "the board Pod is Running"
  ready="$(kubectl get pod -n k-06-never-ready -l app=board -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>&1)"
  assert_eq "$ready" "false" "the board Pod is not Ready (0/1)"
  assert_contains "$(kubectl get events -n k-06-never-ready 2>&1)" "Readiness probe failed" "events show Readiness probe failed"
  # The EndpointSlice still lists the Pod's address, but marked ready:false (so no traffic is sent to it).
  assert_contains "$(kubectl get endpointslices -n k-06-never-ready -l kubernetes.io/service-name=board -o jsonpath='{..conditions}' 2>&1)" '"ready":false' "the Service's endpoint is marked not ready"
  assert_eq "$(kubectl get endpoints board -n k-06-never-ready -o jsonpath='{.subsets[*].addresses}' 2>/dev/null)" "" "the Service has no ready endpoints"
}

fixed() {
  kubectl rollout status deployment/board -n k-06-never-ready --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "board Deployment rolled out (Ready 1/1)"
  assert_eq "$(in_cluster_http_wait k-06-never-ready http://board/healthcheck.php 200)" "200" "board answers 200 via the Service"
  local i seen=""
  for i in 1 2 3 4 5; do
    if kubectl logs visitor -n k-06-never-ready --tail=3 2>/dev/null | grep -q "✅"; then seen=yes; break; fi
    sleep 2
  done
  assert_eq "$seen" "yes" "visitor logs show ✅ within 10 s"
}
