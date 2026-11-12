#!/usr/bin/env bash
# Spec for scenario K33 (33-canteen-two-bugs). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-33-canteen"
CHECK33="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/33-canteen-two-bugs" && pwd)/check.sh"

endpoint_addrs33() { kubectl get endpointslices -n k-33-canteen -l kubernetes.io/service-name=canteen -o jsonpath='{..addresses}' 2>&1; }

# check.sh also wants the visitor to have been served, which takes a few seconds after a fix.
check_passes33() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK33" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

broken() {
  kubectl rollout status deployment/canteen -n k-33-canteen --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "canteen Deployment is Ready"
  assert_eq "$(endpoint_addrs33)" "" "bug 1: the Service has no endpoint addresses"
  assert_eq "$(kubectl get service canteen -n k-33-canteen -o jsonpath='{.spec.ports[0].targetPort}' 2>&1)" "8080" "bug 2: the Service knocks on port 8080"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK33"
  # The boss claim: fixing only the first bug is not enough. Point the Service at the Pods' label
  # and the endpoints appear, but the connection is still refused (nothing listens on 8080).
  kubectl patch service canteen -n k-33-canteen --type merge -p '{"spec":{"selector":{"app":"cantene"}}}' >/dev/null 2>&1
  assert_eq "$([ -n "$(endpoint_addrs33)" ] && echo yes || echo no)" "yes" "after fixing only the selector, endpoints exist"
  assert_eq "$(in_cluster_http k-33-canteen http://canteen)" "000" "...but the connection is still refused (bug 2 is hiding behind bug 1)"
}

fixed() {
  kubectl rollout status deployment/canteen -n k-33-canteen --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "canteen Deployment rolled out"
  assert_eq "$([ -n "$(endpoint_addrs33)" ] && echo yes || echo no)" "yes" "the Service now has endpoint addresses"
  check_passes33
  assert_eq "$?" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-33-canteen http://canteen 200)" "200" "canteen answers 200 inside the cluster"
}
