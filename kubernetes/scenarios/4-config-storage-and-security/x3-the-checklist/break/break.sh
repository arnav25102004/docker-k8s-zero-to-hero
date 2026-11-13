#!/usr/bin/env bash
# S4.x3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-44-checklist"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
refused() { [ -n "$(kubectl get rs -n "$NS" -l app=cart -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>/dev/null)" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9244 || die "Port 9244 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null || die "Could not label the namespace."
say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the ReplicaSet to be refused (the Deployment shows 0 Pods)" 90 refused \
  || die "The Pods were not refused as expected. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The kitchen cart is set up, and the visitor is waiting. Watch it with: kubectl logs -f visitor -n k-44-checklist (Ctrl+C to stop)." \
  "kubectl get deployment,pods -n k-44-checklist"
