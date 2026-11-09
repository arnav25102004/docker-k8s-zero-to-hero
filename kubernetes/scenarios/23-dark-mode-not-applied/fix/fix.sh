#!/usr/bin/env bash
# K23 fix: restart the Deployment, so the Pod starts again with the current ConfigMap values.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-23-dark-mode"

# The old Pod pauses briefly before it stops (preStop): wait until only the new Pod is left.
one_pod() { [ "$(kubectl get pods -n "$NS" -l app=theme --no-headers 2>/dev/null | wc -l | tr -d ' ')" = "1" ]; }

need_cluster
say "Restarting the theme Deployment…"
kubectl rollout restart deployment/theme -n "$NS" >/dev/null || die "kubectl rollout restart failed. Is the scenario running? Try break.sh first."
kubectl rollout status deployment/theme -n "$NS" --timeout=180s >/dev/null \
  || die "The page didn't become Ready. Check: kubectl get pods -n $NS"
wait_for "the old Pod to be removed" 60 one_pod \
  || die "The old Pod is still there. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/theme 9223:80   (in a second terminal; then open http://localhost:9223; on a playground add --address 0.0.0.0 and open the URL for port 9223)"
