#!/usr/bin/env bash
# K20 break: deploys the Cats vs Dogs app (no resources section) and a visitor; the app starts crashing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-20-limitrange"

# Wait until Kubernetes has recorded a kill (OOMKilled, or Error with exit 137 on some runtimes) for the app.
killed() {
  local r e
  r=$(kubectl get pods -n "$NS" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}' 2>/dev/null)
  e=$(kubectl get pods -n "$NS" -l app=showdown -o jsonpath='{range .items[*]}{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}{end}' 2>/dev/null)
  case "$r" in *OOMKilled*) return 0 ;; esac
  case "$e" in *137*) return 0 ;; esac
  return 1
}

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9220 || die "Port 9220 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Deploying the Cats vs Dogs app and a visitor…"
# Namespace settings first: they only affect Pods created after they exist.
kubectl apply -f "$HERE/limitrange.yaml" >/dev/null || die "kubectl apply of the LimitRange failed. Is the cluster healthy?"
kubectl apply -f "$HERE/app.yaml" -f "$HERE/visitor.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app Pods to start misbehaving" 180 killed \
  || die "Expected the app to start crashing, but it didn't. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The app was deployed, but its Pods keep restarting and never become Ready. The visitor can't reach it either. Watch it with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
