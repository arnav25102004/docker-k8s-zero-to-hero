#!/usr/bin/env bash
# K16 fix: the game Deployment gets a toleration for z2h-vip=true:NoSchedule. The taint stays on the nodes.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-16-vip-node"

need_cluster
say "Giving the game a toleration for the VIP taint…"
# A Pod template can be changed in place: the Deployment replaces the Pending Pods with new ones that are allowed to land.
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the rollout (the first time, the nginx image downloads now: up to a minute or two)…"
kubectl rollout status deployment/game -n "$NS" --timeout=180s \
  || die "The game didn't roll out. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS -o wide" \
  "kubectl port-forward -n $NS svc/game 9216:80   (in a second terminal; then open http://localhost:9216; on a playground add --address 0.0.0.0 and open the URL for port 9216)"
