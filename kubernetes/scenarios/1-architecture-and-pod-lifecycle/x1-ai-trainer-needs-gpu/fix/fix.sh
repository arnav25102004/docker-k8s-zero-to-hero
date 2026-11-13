#!/usr/bin/env bash
# S1.x1 fix: the GPU becomes a preference (preferred node affinity) instead of a requirement (nodeSelector).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-17-needs-gpu"

rolled_out() { kubectl rollout status deployment/trainer -n "$NS" --timeout=2s; }
trained() { kubectl logs -n "$NS" -l app=trainer 2>&1 | grep -q "model trained"; }

need_cluster
say "Changing the GPU from a requirement to a preference…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

# On a cold cluster the python image (about 19 MB) downloads now, so allow time.
wait_for "the trainer to be rolled out" 180 rolled_out \
  || die "The trainer didn't become Ready. Check: kubectl get pods -n $NS"
wait_for "the model to finish training" 60 trained \
  || die "The training didn't finish. Check: kubectl logs -n $NS -l app=trainer"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS -o wide" \
  "kubectl logs -n $NS -l app=trainer"
