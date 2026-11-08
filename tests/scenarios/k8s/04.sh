#!/usr/bin/env bash
# Spec for scenario K04 (04-it-tools-no-endpoints). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-04-no-endpoints"

broken() {
  kubectl rollout status deployment/tools -n k-04-no-endpoints --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "tools Pods are Running and Ready"
  assert_eq "$(kubectl get endpointslices -n k-04-no-endpoints -l kubernetes.io/service-name=tools -o jsonpath='{..addresses}' 2>&1)" "" "the Service has no endpoint addresses"
  local code
  code="$(in_cluster_http k-04-no-endpoints http://tools)"
  assert_eq "$([ "$code" != "200" ] && echo yes || echo no)" "yes" "http://tools does not answer 200 (got $code)"
}

fixed() {
  kubectl rollout status deployment/tools -n k-04-no-endpoints --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "tools Deployment rolled out"
  local addrs
  addrs="$(kubectl get endpointslices -n k-04-no-endpoints -l kubernetes.io/service-name=tools -o jsonpath='{..addresses}' 2>&1)"
  assert_eq "$([ -n "$addrs" ] && echo yes || echo no)" "yes" "the Service now has endpoint addresses"
  assert_eq "$(in_cluster_http k-04-no-endpoints http://tools)" "200" "tools answers 200 inside the cluster"
  local i seen=""
  for i in 1 2 3 4 5; do
    if kubectl logs visitor -n k-04-no-endpoints --tail=3 2>/dev/null | grep -q "✅"; then seen=yes; break; fi
    sleep 2
  done
  assert_eq "$seen" "yes" "visitor logs show ✅ within 10 s"
}
