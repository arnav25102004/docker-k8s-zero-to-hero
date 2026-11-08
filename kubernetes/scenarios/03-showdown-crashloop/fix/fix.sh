#!/usr/bin/env bash
# K03 fix: the same Deployment, with PORT set to the number 8080.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-03-crashloop"

rolled_out() { kubectl rollout status deployment/showdown -n "$NS" --timeout=2s; }

# The old, crashing Pod is removed shortly after the new one is Ready: wait until only one Pod is left.
one_pod() { [ "$(kubectl get pods -n "$NS" -l app=showdown --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "1" ]; }

need_cluster
say "Correcting PORT (eighty → 8080)…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app to be rolled out and Ready" 180 rolled_out \
  || die "The app didn't become Ready. Check: kubectl get pods -n $NS"

wait_for "the old crashing Pod to be removed" 60 one_pod \
  || die "The old Pod is still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/showdown 9203:80   (in a second terminal; then open http://localhost:9203; on a playground add --address 0.0.0.0 and open the URL for port 9203)"
