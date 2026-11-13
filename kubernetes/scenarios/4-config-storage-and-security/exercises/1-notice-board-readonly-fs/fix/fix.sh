#!/usr/bin/env bash
# S4.x1 fix: keep the policy, give nginx a scratch folder (emptyDir) at /tmp, the one place it writes.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-22-readonly-fs"

need_cluster
say "Giving the board a scratch folder where it needs to write…"
# A Pod template can be changed in place: the Deployment replaces the crashing Pods with new ones.
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the rollout…"
kubectl rollout status deployment/board -n "$NS" --timeout=180s \
  || die "The board didn't roll out. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/board 9222:80   (in a second terminal; then open http://localhost:9222; on a playground add --address 0.0.0.0 and open the URL for port 9222)"
