#!/usr/bin/env bash
# S5.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-08-oomkilled"

# We wait until Kubernetes has recorded a kill (lastState) AND the previous run's log exists.
killed() {
  [ -n "$(kubectl get pod -n "$NS" -l app=trainer -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)" ] || return 1
  kubectl logs -n "$NS" -l app=trainer --previous 2>&1 | grep -q "epoch 3/6"
}

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Starting the AI trainer with a 64Mi memory limit…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the trainer to be killed" 180 killed \
  || die "Expected the trainer to be killed, but it wasn't. Run cleanup.sh and try again."

scene_set
