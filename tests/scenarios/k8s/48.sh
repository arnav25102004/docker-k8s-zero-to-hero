#!/usr/bin/env bash
# Spec for scenario K48 (48-the-slow-memory-ramp). Needs the monitoring stack (lab K19).
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-48-ramp"
CHECK48="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/48-the-slow-memory-ramp" && pwd)/check.sh"
ensure_monitoring || exit 1

killed48() { kubectl get pods -n k-48-ramp -l app=cache -o jsonpath='{.items[*].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null; }

check_passes48() {
  local i
  for i in $(seq 1 20); do
    bash "$CHECK48" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

broken() {
  local i
  for i in $(seq 1 100); do
    case "$(killed48)" in *OOMKilled*) break ;; esac
    sleep 3
  done
  assert_contains "$(killed48)" "OOMKilled" "the cache is OOM-killed when its memory climbs"
  prom_wait 'kube_pod_container_status_last_terminated_reason{namespace="k-48-ramp",reason="OOMKilled"} == 1' 300
  assert_eq "$?" "0" "Prometheus knows the cache was OOM-killed"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK48"
}

fixed() {
  kubectl rollout status deployment/cache -n k-48-ramp --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "cache Deployment rolled out"
  sleep 45
  check_passes48
  assert_eq "$?" "0" "check.sh says: done (bounded, and no new OOM kill after 45 s)"
  assert_eq "$(in_cluster_http_wait k-48-ramp http://cache 200)" "200" "cache answers 200 inside the cluster"
}
