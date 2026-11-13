#!/usr/bin/env bash
# S1.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-37-stuck-pod"

pod_running() { [ "$(kubectl get pod old-stall -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
being_deleted() { [ -n "$(kubectl get pod old-stall -n "$NS" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null)" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Opening the old stall…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
wait_for "the stall to be Running (the first download can take a minute)" 180 pod_running \
  || die "The Pod didn't start. Run cleanup.sh and try again."

say "Closing the old stall (kubectl delete pod old-stall)…"
kubectl delete pod old-stall -n "$NS" --wait=false >/dev/null || die "kubectl delete failed."
wait_for "the delete to be accepted" 30 being_deleted \
  || die "The Pod was not marked for deletion. Run cleanup.sh and try again."

scene_set
