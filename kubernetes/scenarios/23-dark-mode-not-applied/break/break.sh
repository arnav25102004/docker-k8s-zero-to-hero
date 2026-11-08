#!/usr/bin/env bash
# K23 break: deploy the Campus Today page, then the design team switches dark mode on in the config.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-23-dark-mode"

page_ready() { [ "$(kubectl get deployment theme -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "1" ]; }
visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9223 || die "Port 9223 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the Campus Today page and a visitor…"
kubectl apply -f "$HERE/code.yaml" -f "$HERE/config.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"
kubectl apply -f "$HERE/app.yaml" -f "$HERE/visitor.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the theme page to be ready" 180 page_ready \
  || die "The page didn't become ready. Run cleanup.sh and try again."
wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

say "The design team switches dark mode on in the config…"
kubectl patch configmap ui-settings -n "$NS" --type merge -p '{"data":{"THEME":"dark"}}' >/dev/null \
  || die "Could not update the ConfigMap."

show_next \
  "Dark mode is ON in the config. The site is still blinding white. Watch what a visitor sees with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
