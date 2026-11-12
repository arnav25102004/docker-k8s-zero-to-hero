#!/usr/bin/env bash
# Spec for scenario K32 (32-label-on-the-wrong-object). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-32-wrong-object"
CHECK32="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/32-label-on-the-wrong-object" && pwd)/check.sh"

endpoint_addrs32() { kubectl get endpointslices -n k-32-wrong-object -l kubernetes.io/service-name=samosa -o jsonpath='{..addresses}' 2>&1; }

# check.sh also wants the visitor to have been served, which takes a few seconds after a fix.
check_passes32() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK32" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

broken() {
  kubectl rollout status deployment/samosa -n k-32-wrong-object --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "samosa Deployment is Ready"
  assert_eq "$(kubectl get deployment samosa -n k-32-wrong-object -o jsonpath='{.metadata.labels.app}' 2>&1)" "samosa" "the Deployment object wears app=samosa"
  assert_eq "$(kubectl get pods -n k-32-wrong-object -l stall=samosa-fryer -o jsonpath='{.items[0].metadata.labels.app}' 2>&1)" "" "the Pods do not wear app=samosa"
  assert_eq "$(endpoint_addrs32)" "" "the Service has no endpoint addresses"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK32"
}

fixed() {
  kubectl rollout status deployment/samosa -n k-32-wrong-object --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "samosa Deployment rolled out"
  assert_eq "$([ -n "$(endpoint_addrs32)" ] && echo yes || echo no)" "yes" "the Service now has endpoint addresses"
  check_passes32
  assert_eq "$?" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-32-wrong-object http://samosa 200)" "200" "samosa answers 200 inside the cluster"
}
