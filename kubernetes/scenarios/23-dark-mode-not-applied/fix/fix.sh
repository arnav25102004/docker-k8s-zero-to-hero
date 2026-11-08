#!/usr/bin/env bash
# K23 fix: restart the Deployment, so the Pod starts again with the current ConfigMap values.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-23-dark-mode"

need_cluster
say "Restarting the theme Deployment…"
kubectl rollout restart deployment/theme -n "$NS" >/dev/null || die "kubectl rollout restart failed. Is the scenario running? Try break.sh first."
kubectl rollout status deployment/theme -n "$NS" --timeout=180s >/dev/null \
  || die "The page didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/theme 9223:80   (in a second terminal; then open http://localhost:9223; on a playground add --address 0.0.0.0 and open the URL for port 9223)"
