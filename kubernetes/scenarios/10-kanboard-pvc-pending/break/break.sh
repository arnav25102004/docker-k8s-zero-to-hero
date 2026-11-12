#!/usr/bin/env bash
# K10 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-10-pvc-pending"

# NOT "rollout status": it waits for Ready, which never happens here (that is the bug).
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: PVC Pending, and the cluster has said why (event names fast-ssd).
pvc_pending() { [ "$(kubectl get pvc board-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Pending" ]; }
event_seen() { kubectl get events -n "$NS" 2>/dev/null | grep -q "fast-ssd"; }
pod_pending() { [ "$(kubectl get pod -n "$NS" -l app=board -o jsonpath='{.items[0].status.phase}' 2>/dev/null)" = "Pending" ]; }
visitor_failing() { kubectl logs visitor -n "$NS" --tail=3 2>/dev/null | grep -q "❌"; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9210 || die "Port 9210 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying Kanboard with its disk request, a Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the visitor to start (the first download can take a minute)" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

wait_for "the disk request (PVC) to be Pending" 60 pvc_pending \
  || die "The PVC never showed as Pending. Run cleanup.sh and try again."

wait_for "the cluster to explain why" 60 event_seen \
  || die "No event mentioned fast-ssd. Run cleanup.sh and try again."

wait_for "the Kanboard Pod to be Pending" 60 pod_pending \
  || die "Expected the Pod to be Pending. Run cleanup.sh and try again."

wait_for "the visitor to report a failure" 60 visitor_failing \
  || die "The visitor never reported a failure. Run cleanup.sh and try again."

show_next \
  "The task board is waiting for a disk that will never arrive. Watch the visitor with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
