#!/usr/bin/env bash
# S4.5 fix: the board runs on an image that starts as a normal user (nginx-unprivileged, port 8080). The policy stays.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-21-nonroot"

need_cluster
say "Switching the board to an image that runs as a normal user…"
# A Pod template can be changed in place: the Deployment replaces the stuck Pods with new ones.
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the rollout (the first time, the nginx-unprivileged image downloads now: up to a minute or two)…"
kubectl rollout status deployment/board -n "$NS" --timeout=180s \
  || die "The board didn't roll out. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/board 9221:80   (in a second terminal; then open http://localhost:9221; on a playground add --address 0.0.0.0 and open the URL for port 9221)"
