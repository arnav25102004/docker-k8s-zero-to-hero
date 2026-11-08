#!/usr/bin/env bash
# K10 fix: re-create the disk request (PVC) without storageClassName, so the cluster's default StorageClass is used.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-10-pvc-pending"

rolled_out() { kubectl rollout status deployment/board -n "$NS" --timeout=2s; }
pvc_bound() { [ "$(kubectl get pvc board-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Bound" ]; }

need_cluster
say "Removing the stuck disk request and re-creating it without storageClassName…"
# A PVC's storageClassName is immutable: "kubectl apply" on the existing PVC would be rejected.
# So we delete it and create it again. Order matters: a PVC that a Pod still uses is protected
# from deletion (it would hang in Terminating), so the Deployment (and its Pending Pod) goes first.
kubectl delete deployment board -n "$NS" --ignore-not-found --wait=true >/dev/null || die "Could not delete the Deployment."
kubectl delete pvc board-data -n "$NS" --ignore-not-found --wait=true >/dev/null || die "Could not delete the PVC."
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Kanboard Deployment to be Ready" 180 rolled_out \
  || die "The Pod didn't become Ready. Check: kubectl get pods,pvc -n $NS"
wait_for "the disk (PVC) to be Bound" 60 pvc_bound \
  || die "The PVC isn't Bound. Check: kubectl get pvc -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods,pvc -n $NS" \
  "kubectl port-forward -n $NS --address 0.0.0.0 svc/board 9210:80   (in a second terminal; then open http://localhost:9210)"
