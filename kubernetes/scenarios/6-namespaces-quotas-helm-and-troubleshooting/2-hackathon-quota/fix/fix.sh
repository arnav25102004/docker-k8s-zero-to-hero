#!/usr/bin/env bash
# S6.2 fix: the same dashboard, with requests and limits small enough to fit the quota.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-19-hackathon"

rolled_out() { kubectl rollout status deployment/dashboard -n "$NS" --timeout=2s; }

need_cluster
say "Giving the dashboard Pods requests and limits that fit the quota…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "both dashboard Pods to be Ready" 180 rolled_out \
  || die "The dashboard didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get deployment,pods -n $NS" \
  "kubectl describe quota -n $NS" \
  "kubectl port-forward -n $NS svc/dashboard 9219:80   (in a second terminal; then open http://localhost:9219; on a playground add --address 0.0.0.0 and open the URL for port 9219)"
