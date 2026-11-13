#!/usr/bin/env bash
# Spec for scenario K40 (40-stall-that-asked-for-too-much). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-40-limit-max"
CHECK40="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/6-namespaces-quotas-helm-and-troubleshooting/x1-stall-that-asked-for-too-much" && pwd)/check.sh"

ready40() { local r; r="$(kubectl get deployment chaat -n k-40-limit-max -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }
rsmsg40() { kubectl get rs -n k-40-limit-max -l app=chaat -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>&1; }

broken() {
  assert_eq "$(ready40)" "0" "no chaat Pod exists or is Ready"
  assert_contains "$(rsmsg40)" "maximum memory usage per Container is 128Mi" "the ReplicaSet says the namespace maximum was exceeded"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK40"
}

fixed() {
  kubectl rollout status deployment/chaat -n k-40-limit-max --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "chaat Deployment rolled out"
  assert_eq "$(bash "$CHECK40" >/dev/null 2>&1; echo $?)" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-40-limit-max http://chaat 200)" "200" "chaat answers 200 inside the cluster"
}
