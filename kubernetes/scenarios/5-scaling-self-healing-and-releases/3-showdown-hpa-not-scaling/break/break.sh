#!/usr/bin/env bash
# S5.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-25-hpa"

# The autoscaler has tried at least once and reported that it could not compute a CPU reading
# (not just "no metrics yet", which the first few seconds always say).
hpa_cannot_read() {
  local reason msg
  reason=$(kubectl get hpa showdown -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].reason}' 2>/dev/null)
  msg=$(kubectl get hpa showdown -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].message}' 2>/dev/null)
  [ "$reason" = "FailedGetResourceMetric" ] || return 1
  case "$msg" in *"did not receive metrics"* | *"no metrics returned"*) return 1 ;; esac
  return 0
}

load_up() { [ "$(kubectl get pod load -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9225 || die "Port 9225 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Making sure the cluster can measure CPU (installing metrics-server if it is not there; this can take a minute)…"
ensure_metrics_server k25 || die "metrics-server did not become ready. Check: kubectl -n kube-system get pods"

create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Deploying the Cats vs Dogs app, an autoscaler and some traffic…"
kubectl apply -f "$HERE/app.yaml" -f "$HERE/hpa.yaml" -f "$HERE/load.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the load to start" 180 load_up \
  || die "The load Pod didn't start. Run cleanup.sh and try again."

wait_for "the autoscaler to report its first reading" 180 hpa_cannot_read \
  || die "The autoscaler never reported. Run cleanup.sh and try again."

scene_set
