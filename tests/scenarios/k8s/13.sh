#!/usr/bin/env bash
# Spec for scenario K13 (13-lockdown-blocks-dns). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-13-lockdown k-13-probe"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  # The blocked DNS lookup takes 5 s to give up, so allow a long curl timeout (in_cluster_http only waits 5 s).
  local code
  code="$(kubectl run "ihttp-$$-$RANDOM" -n k-13-lockdown --rm -i --restart=Never --quiet --image=curlimages/curl:8.11.1 --command -- curl -s -o /dev/null -w '%{http_code}' --max-time 30 http://showdown/readyz 2>/dev/null)"
  assert_eq "${code:0:3}" "503" "showdown answers 503 on /readyz (cannot look up redis)"
  assert_contains "$(kubectl logs -n k-13-lockdown -l app=showdown --tail=50 2>&1)" "readiness failed" "the app log shows readiness failing"
  assert_contains "$(kubectl logs -n k-13-lockdown -l app=showdown --tail=50 2>&1)" "Try again" "the app log shows a name-resolution error (Try again)"
  assert_cmd_fails "the probe namespace is already gone" kubectl get namespace k-13-probe
}

fixed() {
  kubectl rollout status deployment/showdown -n k-13-lockdown --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(in_cluster_http k-13-lockdown http://showdown/readyz)" "200" "showdown answers 200 on /readyz"
  local before after
  before="$(kubectl run "vote-$$-$RANDOM" -n k-13-lockdown --rm -i --restart=Never --quiet --image=curlimages/curl:8.11.1 --command -- curl -s --max-time 5 http://showdown/api/results 2>/dev/null)"
  kubectl run "vote-$$-$RANDOM" -n k-13-lockdown --rm -i --restart=Never --quiet --image=curlimages/curl:8.11.1 --command -- curl -s --max-time 5 "http://showdown/api/vote?option=cats" >/dev/null 2>&1
  after="$(kubectl run "vote-$$-$RANDOM" -n k-13-lockdown --rm -i --restart=Never --quiet --image=curlimages/curl:8.11.1 --command -- curl -s --max-time 5 http://showdown/api/results 2>/dev/null)"
  assert_contains "$before" '"storage": "redis"' "results come from redis"
  assert_contains "$before" '"cats": 0' "no cat votes yet"
  assert_contains "$after" '"cats": 1' "one vote for cats shows up in /api/results"
}
