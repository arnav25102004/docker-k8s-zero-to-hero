#!/usr/bin/env bash
# Spec for scenario K05 (05-excalidraw-wrong-port). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-05-wrong-port"

broken() {
  kubectl rollout status deployment/draw -n k-05-wrong-port --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "draw Pods are Running and Ready"
  local addrs
  addrs="$(kubectl get endpointslices -n k-05-wrong-port -l kubernetes.io/service-name=draw -o jsonpath='{..addresses}' 2>&1)"
  assert_eq "$([ -n "$addrs" ] && echo yes || echo no)" "yes" "the Service has endpoint addresses"
  assert_eq "$(in_cluster_http k-05-wrong-port http://draw)" "000" "http://draw is refused (000)"
}

fixed() {
  kubectl rollout status deployment/draw -n k-05-wrong-port --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "draw Deployment rolled out"
  assert_eq "$(in_cluster_http_wait k-05-wrong-port http://draw 200)" "200" "draw answers 200 inside the cluster"
  local i seen=""
  for i in 1 2 3 4 5; do
    if kubectl logs visitor -n k-05-wrong-port --tail=3 2>/dev/null | grep -q "✅"; then seen=yes; break; fi
    sleep 2
  done
  assert_eq "$seen" "yes" "visitor logs show ✅ within 10 s"
}
