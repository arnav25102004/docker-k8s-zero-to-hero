#!/usr/bin/env bash
# Spec for scenario K11 (11-showdown-bad-rollout). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-11-bad-rollout"
# pod_reason lives in the scenarios lib (the harness itself does not source it).
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

NS11="k-11-bad-rollout"

# Number of Pods (any ReplicaSet) that are Ready.
ready_pods() { kubectl get pods -n "$NS11" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c true; }

broken() {
  assert_cmd_fails "rollout status times out (rollout is stuck)" kubectl rollout status deployment/showdown -n "$NS11" --timeout=5s
  assert_contains "$(kubectl get pods -n "$NS11" -l app=showdown --no-headers 2>&1)" "CrashLoopBackOff" "a new Pod is in CrashLoopBackOff"
  assert_eq "$(ready_pods)" "3" "the 3 old Pods are still Ready"
  assert_eq "$(in_cluster_http_wait "$NS11" http://showdown/healthz 200)" "200" "the Service still answers 200 (old Pods serve)"
  assert_contains "$(kubectl rollout history deployment/showdown -n "$NS11" 2>&1)" "v2 Friday release" "history shows the v2 change-cause"
}

fixed() {
  kubectl rollout status deployment/showdown -n "$NS11" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(ready_pods)" "3" "all 3 Pods are Ready"
  assert_eq "$(kubectl get pods -n "$NS11" -l app=showdown --no-headers 2>&1 | wc -l | tr -d ' ')" "3" "exactly 3 Pods are left"
  assert_eq "$(kubectl get deployment showdown -n "$NS11" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_VERSION")].value}')" "1.0.0" "the Deployment is back on APP_VERSION 1.0.0"
  assert_eq "$(kubectl rollout history deployment/showdown -n "$NS11" 2>&1 | grep -c '^3 ')" "1" "history shows a new revision (3)"
  assert_eq "$(in_cluster_http_wait "$NS11" http://showdown/healthz 200)" "200" "showdown answers 200 inside the cluster"
}
