#!/usr/bin/env bash
# S6.x2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-42-qos"

all_running() { for d in cache web batch; do [ "$(kubectl get pods -n "$NS" -l app=$d -o jsonpath='{.items[0].status.phase}' 2>/dev/null)" = "Running" ] || return 1; done; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the three workloads to be Running (the first download can take a minute)" 180 all_running \
  || die "The Pods did not start. Run cleanup.sh and try again."

scene_set
