#!/usr/bin/env bash
# K22 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-22-readonly-fs"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: the board Pods start, stop, and start again (a restart loop).
board_stuck() { [ "$(pod_reason "$NS" app=board)" = "CrashLoopBackOff" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9222 || die "Port 9222 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the Exam Week Board (2 Pods), its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

wait_for "the notice board Pods to settle" 180 board_stuck \
  || die "The notice board Pods didn't settle. Run cleanup.sh and try again."

show_next \
  "The notice board is deployed, but it's not coming up after yesterday's policy rollout. The visitor can't reach it: watch it with kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
