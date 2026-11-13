#!/usr/bin/env bash
# S1.1 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-01-pending"

stuck() {
  [ "$(pod_reason "$NS" app=draw)" = "Pending" ] \
    && kubectl get events -n "$NS" 2>/dev/null | grep -q "Insufficient memory"
}

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9201 || die "Port 9201 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the whiteboard (Excalidraw) and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Pod to be refused by the scheduler" 180 stuck \
  || die "Expected a Pending Pod, but didn't see it. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The whiteboard was deployed, but no Pod is running. The visitor can't reach it either. Watch it with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
