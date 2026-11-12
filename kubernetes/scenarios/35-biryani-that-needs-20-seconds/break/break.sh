#!/usr/bin/env bash
# K35 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-35-slow-biryani"

pods_exist() { [ "$(kubectl get pods -n "$NS" -l app=biryani -o name 2>/dev/null | grep -c .)" -ge 2 ]; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9235 || die "Port 9235 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Opening the stall and sending in a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the stall's Pods to be created (the first download can take a minute)" 180 pods_exist \
  || die "The Pods were not created. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The biryani counter keeps opening and closing, and the Pods keep restarting. Watch it with: kubectl get pods -n k-35-slow-biryani -w (Ctrl+C to stop)." \
  "kubectl logs -f visitor -n k-35-slow-biryani"
