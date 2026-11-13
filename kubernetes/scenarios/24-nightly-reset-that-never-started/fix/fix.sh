#!/usr/bin/env bash
# K24 fix: the CronJob is no longer suspended; wait for the next run.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-24-cronjob"

ran() { [ -n "$(kubectl get cronjob nightly-reset -n "$NS" -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null)" ]; }

need_cluster
say "Resuming the nightly reset…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the next scheduled minute to run the job (up to about 90 seconds)" 180 ran \
  || die "No run finished yet. Check: kubectl get cronjob,jobs -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl get jobs -n $NS   ·   kubectl logs job/<one of the jobs> -n $NS"
