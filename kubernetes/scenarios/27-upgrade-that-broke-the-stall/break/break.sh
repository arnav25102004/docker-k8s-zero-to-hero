#!/usr/bin/env bash
# K27 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-27-helm"

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
bad_pod() { kubectl get pods -n "$NS" -l app=stall -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null | grep -qE 'ErrImagePull|ImagePullBackOff'; }

need_cluster
command -v helm >/dev/null 2>&1 || die "This scenario uses Helm and it isn't installed. macOS: brew install helm · Windows: winget install Helm.Helm · Linux: https://helm.sh/docs/intro/install/"
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Installing the stall with Helm (revision 1)…"
helm install stall "$HERE/../chart/stall" -n "$NS" --wait --timeout 3m >/dev/null \
  || die "helm install failed. Is the cluster healthy? (kubectl get pods -n $NS)"
kubectl apply -f "$HERE/visitor.yaml" >/dev/null || die "Could not start the visitor."
wait_for "the visitor to start" 180 visitor_up || die "The visitor Pod didn't start. Run cleanup.sh and try again."

say "Shipping an upgrade with Helm (revision 2)…"
helm upgrade stall "$HERE/../chart/stall" -n "$NS" --set image.tag=9.9.9 >/dev/null \
  || die "helm upgrade failed. Run cleanup.sh and try again."
wait_for "the new Pod to fail its image pull" 120 bad_pod || die "The upgrade did not break as expected. Run cleanup.sh and try again."

show_next \
  "Helm says the upgrade was deployed. The visitor still sees the stall. Something is not right. Look: helm list -n k-27-helm" \
  "helm history stall -n k-27-helm   ·   kubectl get pods -n k-27-helm"
