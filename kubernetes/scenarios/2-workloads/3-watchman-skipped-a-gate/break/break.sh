#!/usr/bin/env bash
# S2.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-16-daemonset"

scene_ready() { [ -n "$(kubectl get daemonset watchman -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

# Hang a "reserved" sign (a taint) on ONE gate (node), the last one in the list. cleanup.sh removes it.
NODE=$(kubectl get nodes -o name | tail -n 1)
say "Reserving one node with a taint (cleanup.sh removes it): ${NODE#node/}…"
kubectl taint nodes "${NODE#node/}" z2h-vip=true:NoSchedule --overwrite >/dev/null || die "Could not taint the node."

say "Posting a watchman at every gate…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the DaemonSet to count its gates" 120 scene_ready \
  || die "The DaemonSet did not report. Run cleanup.sh and try again."
sleep 5

show_next \
  "A watchman was posted at every gate. Count the gates, then count the watchmen." \
  "kubectl get nodes   ·   kubectl get daemonset,pods -n k-16-daemonset -o wide"
