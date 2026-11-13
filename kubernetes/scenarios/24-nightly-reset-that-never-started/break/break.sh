#!/usr/bin/env bash
# K24 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-24-cronjob"

scene_ready() { kubectl get cronjob nightly-reset -n "$NS" >/dev/null 2>&1; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Scheduling the nightly reset…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
wait_for "the CronJob to exist" 60 scene_ready || die "The CronJob was not created. Run cleanup.sh and try again."

show_next \
  "The nightly reset is scheduled to run every minute. Give it two minutes. Did it run?" \
  "kubectl get cronjob,jobs -n k-24-cronjob"
