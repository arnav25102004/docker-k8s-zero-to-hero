#!/usr/bin/env bash
# S1.x3 fix: point the log shipper at the file the web container really writes.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-29-sidecar"

need_cluster
say "Fixing the log shipper's setting…"
# A Pod template can be changed in place: the Deployment replaces the old Pod with a new one.
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the rollout…"
kubectl rollout status deployment/notice -n "$NS" --timeout=180s \
  || die "The notice board didn't roll out. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/notice 9229:80   (in a second terminal; then open http://localhost:9229; on a playground add --address 0.0.0.0 and open the URL for port 9229)"
