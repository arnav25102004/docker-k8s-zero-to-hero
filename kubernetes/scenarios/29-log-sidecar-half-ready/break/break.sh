#!/usr/bin/env bash
# K29 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-29-sidecar"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended state: one container of the notice Pod is ready and the other is running but not ready.
half_ready() {
  local r
  r="$(kubectl get pods -n "$NS" -l app=notice -o jsonpath='{range .items[0].status.containerStatuses[*]}{.ready}{" "}{end}' 2>/dev/null)"
  case "$r" in
    *true*false* | *false*true*) return 0 ;;
  esac
  return 1
}

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9229 || die "Port 9229 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the Hostel Notice Board (one Pod, two containers), its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the visitor to start (the first download can take a minute)" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."
wait_for "the notice board Pod to settle (the first download can take a minute)" 180 half_ready \
  || die "The notice board Pod didn't settle. Run cleanup.sh and try again."

show_next \
  "The notice board is deployed, but the site is not answering. The visitor sees it live: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
