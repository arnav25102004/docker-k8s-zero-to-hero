#!/usr/bin/env bash
# K15 fix: the readiness probe asks the right port, and the stuck Pod is replaced.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-15-statefulset"

settled() { [ "$(kubectl get statefulset stall -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "3" ]; }

need_cluster
say "Pointing the readiness probe at the port the stall really listens on…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
# A StatefulSet will not replace a Pod that never became Ready (it waits for it). Delete the stuck Pod
# so the controller recreates it from the corrected template.
say "stall-0 never became Ready, so the StatefulSet would wait for it forever. Replacing it…"
kubectl delete pod stall-0 -n "$NS" --wait=false >/dev/null 2>&1 || true

wait_for "all three stalls to open, one after another" 240 settled \
  || die "The stalls did not all open. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now check it yourself:" \
  "./check.sh   ·   kubectl get pods -n $NS"
