#!/usr/bin/env bash
# Spec for scenario K45 (45-the-locked-down-kitchen). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-45-lockdown"
CHECK45="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/4-config-storage-and-security/exercises/4-the-locked-down-kitchen" && pwd)/check.sh"

ready45() { local r; r="$(kubectl get deployment kitchen -n k-45-lockdown -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }
rsmsg45() { kubectl get rs -n k-45-lockdown -l app=kitchen -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>&1; }

reasons45() { kubectl get pods -n k-45-lockdown -l app=kitchen -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null; }
events45() { kubectl get events -n k-45-lockdown -o jsonpath='{.items[*].message}' 2>&1; }

broken() {
  assert_eq "$(ready45)" "0" "no kitchen Pod is Ready"
  assert_contains "$(reasons45)" "CreateContainerConfigError" "the Pods were admitted but cannot start"
  assert_contains "$(events45)" "runAsNonRoot" "the events say the image would run as root"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK45"
}

fixed() {
  kubectl rollout status deployment/kitchen -n k-45-lockdown --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "kitchen Deployment rolled out"
  assert_eq "$(bash "$CHECK45" >/dev/null 2>&1; echo $?)" "0" "check.sh says: done (guard still on)"
  assert_eq "$(in_cluster_http_wait k-45-lockdown http://kitchen 200)" "200" "kitchen answers 200 inside the cluster"
}
