#!/usr/bin/env bash
# K24 fix: the same Deployment, corrected.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-24-never-ran"

rolled_out() { kubectl rollout status deployment/showdown -n "$NS" --timeout=2s; }

# The old Pod is removed shortly after the new one is Ready: wait until only one Pod is left.
one_pod() { [ "$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "1" ]; }

need_cluster
say "Applying the corrected Deployment…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app to be rolled out and Ready" 180 rolled_out \
  || die "The app didn't become Ready. Check: kubectl get pods -n $NS"

wait_for "the old Pod to be removed" 60 one_pod \
  || die "The old Pod is still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/showdown 9224:80   (in a second terminal; then open http://localhost:9224; on a playground add --address 0.0.0.0 and open the URL for port 9224)"
