#!/usr/bin/env bash
# K27 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-27-config-key"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: the dashboard Pod exists, is not Running, and the kubelet has reported a mount event.
stuck() {
  [ "$(pod_reason "$NS" app=dashboard)" = "ContainerCreating" ] &&
    kubectl get events -n "$NS" --field-selector reason=FailedMount -o name 2>/dev/null | grep -q .
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9227 || die "Port 9227 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the Campus quick links dashboard and a visitor…"
kubectl apply -f "$HERE/links.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
kubectl apply -f "$HERE/app.yaml" -f "$HERE/visitor.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "the dashboard Pod to show its first problem" 180 stuck \
  || die "The expected problem didn't show up. Run cleanup.sh and try again."

show_next \
  "The dashboard is deployed and the visitor can't reach it. Watch what a visitor sees with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
