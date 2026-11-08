#!/usr/bin/env bash
# K07 fix: the same Deployment, plus a startupProbe that gives the app up to 60 s to wake up.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-07-slow-start"

rolled_out() { kubectl rollout status deployment/showdown -n "$NS" --timeout=2s; }

# The old, restarting Pod is removed shortly after the new one is Ready: wait until only one Pod is left.
one_pod() { [ "$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "1" ]; }

need_cluster
say "Adding a startupProbe (up to 60 s to wake up)…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app to be rolled out and Ready (the app needs about 20 s)" 180 rolled_out \
  || die "The app didn't become Ready. Check: kubectl get pods -n $NS"

wait_for "the old restarting Pod to be removed" 60 one_pod \
  || die "The old Pod is still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS --address 0.0.0.0 svc/showdown 9207:80   (in a second terminal; then open http://localhost:9207)"
