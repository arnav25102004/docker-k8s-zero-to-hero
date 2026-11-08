#!/usr/bin/env bash
# K06 fix: the readiness probe now checks /healthcheck.php, which Kanboard really serves.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-06-never-ready"

rolled_out() { kubectl rollout status deployment/board -n "$NS" --timeout=2s; }

need_cluster
say "Pointing the readiness probe at a path Kanboard really has (/healthz.php → /healthcheck.php)…"
# Changing the probe changes the Pod template, so Kubernetes rolls out a new Pod by itself.
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Kanboard Deployment to be Ready" 180 rolled_out \
  || die "The Pod didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS --address 0.0.0.0 svc/board 9206:80   (in a second terminal; then open http://localhost:9206)"
