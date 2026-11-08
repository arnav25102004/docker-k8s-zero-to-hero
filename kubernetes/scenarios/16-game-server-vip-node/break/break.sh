#!/usr/bin/env bash
# K16 break: every node gets the taint z2h-vip=true:NoSchedule, then the game is deployed without a toleration.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-16-vip-node"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: the game Pods exist but the scheduler refused them (phase Pending).
game_pending() {
  [ "$(kubectl get pods -n "$NS" -l app=game --no-headers 2>/dev/null | grep -c ' Pending ')" -ge 1 ] &&
    kubectl get events -n "$NS" 2>/dev/null | grep -q 'FailedScheduling'
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9216 || die "Port 9216 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Applying a cluster-wide node change (cleanup.sh reverts it)…"
# --all also covers a control-plane node that already has its own taint, and the only node of a 1-node cluster.
# --overwrite makes a re-run harmless. NoSchedule only stops NEW Pods; Pods already running stay.
kubectl taint nodes --all z2h-vip=true:NoSchedule --overwrite >/dev/null || die "Could not taint the nodes."

say "Deploying Dosa Dash (2 Pods), its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

wait_for "the game Pods to be refused by the scheduler" 60 game_pending \
  || die "The game Pods never showed up as Pending. Run cleanup.sh and try again."

show_next \
  "Dosa Dash is deployed, the nodes are up, and yet the game Pods are stuck in Pending. The visitor can't reach it: watch it with kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
