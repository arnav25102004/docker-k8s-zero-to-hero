#!/usr/bin/env bash
# K06 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-06-never-ready"

# NOT "rollout status": it waits for Ready, which never happens here (that is the bug).
board_running() { [ "$(kubectl get pod -n "$NS" -l app=board -o jsonpath='{.items[0].status.phase}' 2>/dev/null)" = "Running" ]; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: Running but not Ready, and the kubelet has reported the failed probe.
probe_failed() { kubectl get events -n "$NS" 2>/dev/null | grep -q "Readiness probe failed"; }
not_ready() { [ "$(kubectl get pod -n "$NS" -l app=board -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "false" ]; }
visitor_failing() { kubectl logs visitor -n "$NS" --tail=3 2>/dev/null | grep -q "❌"; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9206 || die "Port 9206 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying Kanboard, its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Kanboard Pod to start (the first download can take a minute)" 180 board_running \
  || die "The Pod didn't start. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

wait_for "the readiness probe to fail" 120 probe_failed \
  || die "The probe never reported a failure. Run cleanup.sh and try again."

not_ready || die "Expected the Pod to be Running but not Ready. Run cleanup.sh and try again."

wait_for "the visitor to report a failure" 60 visitor_failing \
  || die "The visitor never reported a failure. Run cleanup.sh and try again."

show_next \
  "The Kanboard Pod is Running, yet nobody gets served. Watch the visitor with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
