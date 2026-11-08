#!/usr/bin/env bash
# K08 fix: the same trainer with a 256Mi memory limit (request 200Mi), so it can finish.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-08-oomkilled"

rolled_out() { kubectl rollout status deployment/trainer -n "$NS" --timeout=2s; }
trained() { kubectl logs -n "$NS" -l app=trainer 2>&1 | grep -q "model trained"; }

need_cluster
say "Raising the memory limit to 256Mi…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the trainer to be rolled out" 180 rolled_out \
  || die "The trainer didn't become Ready. Check: kubectl get pods -n $NS"
wait_for "the model to finish training" 60 trained \
  || die "The training didn't finish. Check: kubectl logs -n $NS -l app=trainer"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl logs -n $NS -l app=trainer"
