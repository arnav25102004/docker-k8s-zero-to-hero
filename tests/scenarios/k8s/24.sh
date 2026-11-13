#!/usr/bin/env bash
# Spec for scenario K24 (24-nightly-reset-that-never-started). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-24-cronjob"
CHECK24="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../kubernetes/scenarios/24-nightly-reset-that-never-started" && pwd)/check.sh"

check_passes24() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    bash "$CHECK24" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

broken() {
  sleep 70
  assert_eq "$(kubectl get cronjob nightly-reset -n k-24-cronjob -o jsonpath='{.spec.suspend}' 2>&1)" "true" "the CronJob is suspended"
  assert_eq "$(kubectl get jobs -n k-24-cronjob --no-headers 2>/dev/null | wc -l | tr -d ' ')" "0" "no Job was created in over a minute"
  assert_eq "$(kubectl get cronjob nightly-reset -n k-24-cronjob -o jsonpath='{.status.lastScheduleTime}' 2>&1)" "" "it has never been scheduled"
  assert_cmd_fails "check.sh says: not done yet" bash "$CHECK24"
}

fixed() {
  assert_eq "$(kubectl get cronjob nightly-reset -n k-24-cronjob -o jsonpath='{.spec.suspend}' 2>&1)" "false" "the CronJob is no longer suspended"
  check_passes24
  assert_eq "$?" "0" "check.sh says: done"
  assert_contains "$(kubectl logs -n k-24-cronjob -l job-name --tail=3 2>&1)" "leaderboard reset" "a Job's log says the leaderboard was reset"
}
