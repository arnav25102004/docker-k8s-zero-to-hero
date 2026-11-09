#!/usr/bin/env bash
# Spec for scenario K26 (26-showdown-init-stuck). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-26-init-stuck"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

NS26="k-26-init-stuck"

broken() {
  assert_contains "$(kubectl get pods -n "$NS26" -l app=showdown --no-headers 2>&1)" "Init:0/1" "the app Pod is stuck in Init:0/1"
  assert_contains "$(kubectl logs -n "$NS26" -l app=showdown -c wait-for-redis 2>&1)" "waiting for redsi" "the init container log says it is waiting for redsi"
}

fixed() {
  kubectl rollout status deployment/showdown -n "$NS26" --timeout=180s >/dev/null 2>&1
  assert_eq "$?" "0" "showdown Deployment rolled out"
  assert_eq "$(in_cluster_http "$NS26" http://showdown/readyz)" "200" "showdown answers 200 on /readyz"
  local before after
  before="$(kubectl run "vote-$$-$RANDOM" -n "$NS26" --rm -i --restart=Never --quiet --image=curlimages/curl:8.11.1 --command -- curl -s --max-time 5 http://showdown/api/results 2>/dev/null)"
  kubectl run "vote-$$-$RANDOM" -n "$NS26" --rm -i --restart=Never --quiet --image=curlimages/curl:8.11.1 --command -- curl -s --max-time 5 "http://showdown/api/vote?option=cats" >/dev/null 2>&1
  after="$(kubectl run "vote-$$-$RANDOM" -n "$NS26" --rm -i --restart=Never --quiet --image=curlimages/curl:8.11.1 --command -- curl -s --max-time 5 http://showdown/api/results 2>/dev/null)"
  assert_contains "$before" '"storage": "redis"' "votes are stored in redis"
  assert_contains "$before" '"cats": 0' "no cat votes yet"
  assert_contains "$after" '"cats": 1' "a vote for cats persists in /api/results"
}
