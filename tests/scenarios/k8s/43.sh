#!/usr/bin/env bash
# Spec for scenario K43 (43-maintenance-van-wants-the-master-key). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-43-van"
CHECK43="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/43-maintenance-van-wants-the-master-key" && pwd)/check.sh"

ready43() { local r; r="$(kubectl get deployment van -n k-43-van -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }
rsmsg43() { kubectl get rs -n k-43-van -l app=van -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>&1; }

broken() {
  assert_eq "$(ready43)" "0" "no van Pod is Ready"
  assert_contains "$(rsmsg43)" "privileged" "the ReplicaSet says privileged is not allowed"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK43"
}

fixed() {
  kubectl rollout status deployment/van -n k-43-van --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "van Deployment rolled out"
  assert_eq "$(bash "$CHECK43" >/dev/null 2>&1; echo $?)" "0" "check.sh says: done (guard still on)"
  assert_eq "$(in_cluster_http_wait k-43-van http://van 200)" "200" "van answers 200 inside the cluster"
}
