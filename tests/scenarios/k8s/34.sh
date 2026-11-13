#!/usr/bin/env bash
# Spec for scenario K34 (34-doorbell-on-the-wrong-door). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-34-doorbell"
CHECK34="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/5-scaling-self-healing-and-releases/exercises/1-doorbell-on-the-wrong-door" && pwd)/check.sh"

events34() { kubectl get events -n k-34-doorbell -o jsonpath='{.items[*].message}' 2>&1; }

# wait until a text shows up in the namespace's events (up to 60 s)
wait_event34() {
  local i
  for i in $(seq 1 30); do
    case "$(events34)" in *"$1"*) return 0 ;; esac
    sleep 2
  done
  return 1
}

check_passes34() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK34" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

broken() {
  local i
  for i in $(seq 1 60); do
    [ "$(kubectl get pods -n k-34-doorbell -l app=dosa -o jsonpath='{.items[*].status.phase}' 2>/dev/null)" = "Running Running" ] && break
    sleep 2
  done
  assert_eq "$(kubectl get pods -n k-34-doorbell -l app=dosa -o jsonpath='{.items[*].status.phase}' 2>&1)" "Running Running" "both dosa Pods are Running"
  assert_eq "$(kubectl get pods -n k-34-doorbell -l app=dosa -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>&1)" "false" "...but not Ready"
  assert_eq "$(kubectl get pods -n k-34-doorbell -l app=dosa -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>&1)" "0" "a failing readiness probe restarts nothing"
  wait_event34 "Readiness probe failed"
  assert_contains "$(events34)" "Readiness probe failed" "the events say the readiness probe failed"
  assert_contains "$(events34)" "connection refused" "...because the connection was refused (a wrong port, not a 404)"
  # A Pod that is not Ready still appears in the EndpointSlice, marked ready:false; the Endpoints object lists ready addresses only.
  assert_contains "$(kubectl get endpointslices -n k-34-doorbell -l kubernetes.io/service-name=dosa -o jsonpath='{..conditions}' 2>&1)" '"ready":false' "the Service's endpoints are marked not ready"
  assert_eq "$(kubectl get endpoints dosa -n k-34-doorbell -o jsonpath='{.subsets[*].addresses}' 2>/dev/null)" "" "the Service has no ready endpoints"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK34"
}

fixed() {
  kubectl rollout status deployment/dosa -n k-34-doorbell --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "dosa Deployment rolled out"
  check_passes34
  assert_eq "$?" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-34-doorbell http://dosa 200)" "200" "dosa answers 200 inside the cluster"
}
