#!/usr/bin/env bash
# K24 break: deploys the Cats vs Dogs app and waits for its Pod to settle.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-24-never-ran"

# Settled = the Pod has restarted at least once and a Warning event is recorded.
settled() {
  local restarts
  restarts=$(kubectl get pods -n "$NS" -l app=showdown -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
  [ "${restarts:-0}" -ge 1 ] || return 1
  kubectl get events -n "$NS" --field-selector type=Warning 2>/dev/null | grep -q "showdown"
}

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9224 || die "Port 9224 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Starting Cats vs Dogs…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app Pods to settle" 180 settled \
  || die "The app Pod didn't settle into its failing state. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The app was deployed, but nobody can vote. Watch what a visitor gets: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
