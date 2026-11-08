#!/usr/bin/env bash
# K15 fix: enableServiceLinks: false is a Pod template change, so the Deployment rolls out a new Pod.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-15-mystery-env"

need_cluster
say "Turning off service links for the score worker…"
kubectl apply -f "$HERE/worker.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the new worker Pod to roll out…"
kubectl rollout status deployment/score-worker -n "$NS" --timeout=180s >/dev/null \
  || die "The worker didn't roll out. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl logs -n $NS -l app=score-worker"
