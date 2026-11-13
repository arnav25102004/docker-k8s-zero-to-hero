#!/usr/bin/env bash
# K48 fix: the cache is bounded, so its memory stops climbing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-48-ramp"

settled() { check_rollouts "$NS" >/dev/null 2>&1; }

need_cluster
say "Putting a ceiling on the cache…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the cache to restart with its ceiling" 180 settled \
  || die "It did not settle. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   watch the memory line flatten in Grafana"
