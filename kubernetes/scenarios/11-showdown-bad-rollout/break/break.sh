#!/usr/bin/env bash
# K11 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-11-bad-rollout"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

# Stuck state: a new Pod is in CrashLoopBackOff while the 3 old Pods are still Ready.
# (kubectl rollout status would just block here, so we read the Pods instead.)
stuck() {
  local waiting ready
  waiting=$(kubectl get pods -n "$NS" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].state.waiting.reason}{"\n"}{end}' 2>/dev/null | grep -c CrashLoopBackOff)
  ready=$(kubectl get pods -n "$NS" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c true)
  [ "$waiting" -ge 1 ] && [ "$ready" = "3" ]
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9211 || die "Port 9211 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Releasing v1 (3 replicas)…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
kubectl rollout status deployment/showdown -n "$NS" --timeout=180s >/dev/null \
  || die "v1 didn't become Ready. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

say "🚀 Friday, 6 PM: shipping v2…"
kubectl apply -f "$HERE/v2/" >/dev/null || die "kubectl apply of v2 failed. Is the cluster healthy?"

wait_for "the new Pod to start crashing while the 3 old Pods stay Ready" 180 stuck \
  || die "Expected a stuck rollout, but didn't see it. Run cleanup.sh and try again."

show_next \
  "v2 was released on a Friday evening. Then it went quiet. Is the poll down? Watch what a visitor gets: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
