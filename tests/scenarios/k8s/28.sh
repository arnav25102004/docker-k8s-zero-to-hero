#!/usr/bin/env bash
# Spec for scenario K28 (28-leaderboard-reset-job). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-28-job"
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios" && pwd)/_lib.sh"

broken() {
  assert_eq "$(kubectl get job leaderboard-reset -n k-28-job -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>&1)" "True" "the Job condition is Failed"
  assert_eq "$(kubectl get job leaderboard-reset -n k-28-job -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}' 2>&1)" "BackoffLimitExceeded" "the Job failed with BackoffLimitExceeded"
  local logs
  logs="$(kubectl logs -n k-28-job -l job-name=leaderboard-reset --tail=20 2>&1)"
  assert_contains "$logs" "gaierror" "a Pod log shows a name-resolution error (socket.gaierror)"
  assert_eq "$(kubectl exec -n k-28-job deploy/redis -- redis-cli ZSCORE scores Lakshmi 2>&1)" "120" "the scores are untouched"
}

fixed() {
  kubectl wait --for=condition=complete job/leaderboard-reset -n k-28-job --timeout=120s >/dev/null 2>&1
  assert_eq "$?" "0" "the Job is Complete"
  assert_contains "$(kubectl logs job/leaderboard-reset -n k-28-job 2>&1)" "leaderboard reset" "the logs say leaderboard reset"
  assert_eq "$(kubectl exec -n k-28-job deploy/redis -- redis-cli ZCOUNT scores 1 +inf 2>&1)" "0" "no player has a score above 0"
  assert_eq "$(kubectl exec -n k-28-job deploy/redis -- redis-cli ZCARD scores 2>&1)" "5" "all five players are still on the board"
}
