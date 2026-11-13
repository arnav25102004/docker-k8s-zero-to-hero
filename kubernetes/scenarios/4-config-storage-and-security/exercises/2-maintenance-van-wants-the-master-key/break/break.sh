#!/usr/bin/env bash
# S4.x2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../../_lib.sh"

NS="k-43-van"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
refused() { [ -n "$(kubectl get rs -n "$NS" -l app=van -o jsonpath='{.items[*].status.conditions[?(@.type=="ReplicaFailure")].message}' 2>/dev/null)" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9243 || die "Port 9243 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce=baseline --overwrite >/dev/null || die "Could not label the namespace."
say "Setting the scene…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the ReplicaSet to be refused (the Deployment shows 0 Pods)" 90 refused \
  || die "The Pods were not refused as expected. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

scene_set
