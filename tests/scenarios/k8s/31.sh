#!/usr/bin/env bash
# Spec for scenario K31 (31-two-stalls-one-signboard). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-31-two-stalls"
CHECK31="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/31-two-stalls-one-signboard" && pwd)/check.sh"

endpoint_pods31() { kubectl get endpointslices -n k-31-two-stalls -l kubernetes.io/service-name=chai -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}{"\n"}{end}' 2>&1; }

broken() {
  kubectl rollout status deployment/chai -n k-31-two-stalls --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "chai Deployment is Ready"
  kubectl rollout status deployment/stale-chai -n k-31-two-stalls --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "stale-chai Deployment is Ready"
  assert_contains "$(endpoint_pods31)" "stale-chai-" "the Service also sends customers to the stale stall"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK31"
  assert_eq "$(in_cluster_http_wait k-31-two-stalls http://chai 200)" "200" "customers still get an answer (just not always the fresh one)"
}

fixed() {
  local left
  left="$(endpoint_pods31 | grep -c '^stale-chai-')"
  assert_eq "$left" "0" "no stale address is left behind the Service"
  bash "$CHECK31" >/dev/null 2>&1
  assert_eq "$?" "0" "check.sh says: done"
  assert_eq "$(in_cluster_http_wait k-31-two-stalls http://chai 200)" "200" "chai answers 200 inside the cluster"
}
