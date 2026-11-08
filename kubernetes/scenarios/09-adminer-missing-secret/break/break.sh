#!/usr/bin/env bash
# K09 break: the Pod needs Secret "adminer-db", which is missing, so its container is never created.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-09-missing-secret"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
# The intended failure: the container is stuck in CreateContainerConfigError.
config_error() { [ "$(pod_reason "$NS" app=adminer)" = "CreateContainerConfigError" ]; }
visitor_failing() { kubectl logs visitor -n "$NS" --tail=3 2>/dev/null | grep -q "❌"; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9209 || die "Port 9209 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying Adminer, its Service and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the visitor to start (the first download can take a minute)" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

wait_for "the Adminer Pod to get stuck on its missing Secret" 180 config_error \
  || die "The Pod never reached CreateContainerConfigError. Run cleanup.sh and try again."

wait_for "the visitor to report a failure" 60 visitor_failing \
  || die "The visitor never reported a failure. Run cleanup.sh and try again."

show_next \
  "The database tool won't even start. Watch the visitor with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
