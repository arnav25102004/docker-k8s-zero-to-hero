#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-24-cronjob"
need_cluster
suspended=$(kubectl get cronjob nightly-reset -n "$NS" -o jsonpath='{.spec.suspend}' 2>/dev/null)
last=$(kubectl get cronjob nightly-reset -n "$NS" -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null)
if [ "$suspended" != "true" ] && [ -n "$last" ]; then
  ok "The nightly reset is running again: its last success was at $last."
  exit 0
fi
[ "$suspended" = "true" ] && warn "Not yet: the CronJob is suspended (spec.suspend is true), so it never creates a Job."
[ "$suspended" != "true" ] && [ -z "$last" ] && warn "Not suspended any more, but no run has succeeded yet. Give it up to a minute and run ./check.sh again."
exit 1
