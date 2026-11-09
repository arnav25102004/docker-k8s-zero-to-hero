#!/usr/bin/env bash
# K26 fix: one word in the Pod template changes, so the Deployment rolls out a new Pod.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-26-init-stuck"

# The old Pod is removed shortly after the new one is Ready: wait until only one Pod is left.
one_pod() { [ "$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "1" ]; }

need_cluster
say "Applying the corrected Deployment…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the new Pod to roll out…"
kubectl rollout status deployment/showdown -n "$NS" --timeout=180s >/dev/null \
  || die "The app didn't roll out. Check: kubectl get pods -n $NS"

wait_for "the old Pod to be removed" 60 one_pod \
  || die "The old Pod is still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/showdown 9226:80   (in a second terminal; then open http://localhost:9226; on a playground add --address 0.0.0.0 and open the URL for port 9226)"
