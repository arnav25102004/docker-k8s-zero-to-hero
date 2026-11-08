#!/usr/bin/env bash
# K03 break: the Cats vs Dogs app gets PORT="eighty" (a word), so it crashes on every start.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-03-crashloop"

# First the Pod crashes and restarts; after a couple of crashes the kubelet reports CrashLoopBackOff.
# We wait for that, and for the crash message of the dead container to exist.
looping() {
  [ "$(pod_reason "$NS" app=showdown)" = "CrashLoopBackOff" ] || return 1
  kubectl logs -n "$NS" -l app=showdown --previous 2>&1 | grep -q "ValueError"
}

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9203 || die "Port 9203 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."
create_showdown_configmap "$NS" || die "Could not create the ConfigMap showdown-code."

say "Deploying the Cats vs Dogs app and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the app to start crashing (CrashLoopBackOff)" 180 looping \
  || die "Expected a crash loop, but didn't see it. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The app was deployed, but it keeps starting and dying. The visitor can't reach it either. Watch it with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
