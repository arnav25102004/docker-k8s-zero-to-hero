#!/usr/bin/env bash
# Spec for scenario K12 (12-showdown-dns-namespaces). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-12-dns-app k-12-dns-data"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(in_cluster_http k-12-dns-app http://showdown/readyz)" "503" "showdown answers 503 on /readyz (cannot find redis)"
  assert_contains "$(kubectl logs -n k-12-dns-app -l app=showdown 2>&1)" "Name does not resolve" "the app log shows the name lookup failing"
}

fixed() {
  kubectl rollout status deployment/showdown -n k-12-dns-app --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(in_cluster_http_wait k-12-dns-app http://showdown/readyz 200)" "200" "showdown answers 200 on /readyz"
  local before after
  before="$(in_cluster_pod k-12-dns-app "" curl -s --max-time 5 http://showdown/api/results)"
  in_cluster_pod k-12-dns-app "" curl -s --max-time 5 "http://showdown/api/vote?option=cats" >/dev/null 2>&1
  after="$(in_cluster_pod k-12-dns-app "" curl -s --max-time 5 http://showdown/api/results)"
  assert_contains "$before" '"storage": "redis"' "results come from redis"
  assert_contains "$before" '"cats": 0' "no cat votes yet"
  assert_contains "$after" '"cats": 1' "one vote for cats shows up in /api/results"
}
