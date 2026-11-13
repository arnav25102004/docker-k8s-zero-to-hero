#!/usr/bin/env bash
# S1.2 fix: the same Deployment, with the image name spelled correctly (excalidraw).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-02-image-typo"

rolled_out() { kubectl rollout status deployment/draw -n "$NS" --timeout=2s; }

# The old, stuck Pod is removed shortly after the new one is Ready: wait until only one whiteboard Pod is left.
one_pod() { [ "$(kubectl get pods -n "$NS" -l app=draw --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "1" ]; }

need_cluster
say "Correcting the image name (excalidrw → excalidraw)…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the whiteboard Pod to be Ready" 180 rolled_out \
  || die "The Pod didn't become Ready. Check: kubectl get pods -n $NS"

wait_for "the old stuck Pod to be removed" 60 one_pod \
  || die "The old Pod is still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/draw 9202:80   (in a second terminal; then open http://localhost:9202; on a playground add --address 0.0.0.0 and open the URL for port 9202)"
