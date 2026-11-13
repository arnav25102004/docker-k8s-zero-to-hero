#!/usr/bin/env bash
# Spec for scenario K44 (44-the-checklist). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-44-checklist"
CHECK44="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/4-config-storage-and-security/x3-the-checklist" && pwd)/check.sh"

ready44() { local r; r="$(kubectl get deployment cart -n k-44-checklist -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"; echo "${r:-0}"; }
rsmsg44() { kubectl get rs -n k-44-checklist -l app=cart -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>&1; }

broken() {
  assert_eq "$(ready44)" "0" "no cart Pod is Ready"
  local m; m="$(rsmsg44)"
  assert_contains "$m" "allowPrivilegeEscalation" "the refusal lists allowPrivilegeEscalation"
  assert_contains "$m" "runAsNonRoot" "the refusal lists runAsNonRoot"
  assert_contains "$m" "seccompProfile" "the refusal lists seccompProfile"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK44"
}

fixed() {
  kubectl rollout status deployment/cart -n k-44-checklist --timeout=240s >/dev/null 2>&1
  assert_eq "$?" "0" "cart Deployment rolled out"
  assert_eq "$(bash "$CHECK44" >/dev/null 2>&1; echo $?)" "0" "check.sh says: done (guard still on)"
  assert_eq "$(in_cluster_http_wait k-44-checklist http://cart 200)" "200" "cart answers 200 inside the cluster"
}
