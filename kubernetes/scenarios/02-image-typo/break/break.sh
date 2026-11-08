#!/usr/bin/env bash
# K02 break: the Excalidraw Deployment points at an image name with a typo, so the node can't pull it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-02-image-typo"

# The kubelet reports ErrImagePull right after a failed pull, then ImagePullBackOff while it waits to retry.
# Either one is the intended failure; we also wait for the pull error to appear in the Events.
stuck() {
  case "$(pod_reason "$NS" app=draw)" in
    ErrImagePull | ImagePullBackOff) ;;
    *) return 1 ;;
  esac
  kubectl get events -n "$NS" 2>/dev/null | grep -q "pull"
}

visitor_up() { [ "$(kubectl get pod visitor -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

need_cluster
bash "$HERE/../cleanup.sh"
port_free 9202 || die "Port 9202 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the whiteboard (Excalidraw) and a visitor…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the image pull to fail" 180 stuck \
  || die "Expected an image pull failure, but didn't see it. Run cleanup.sh and try again."

wait_for "the visitor to start" 180 visitor_up \
  || die "The visitor Pod didn't start. Run cleanup.sh and try again."

show_next \
  "The whiteboard was deployed, but no Pod is running. The visitor can't reach it either. Watch it with: kubectl logs -f visitor -n $NS (Ctrl+C to stop)." \
  "kubectl get pods -n $NS"
