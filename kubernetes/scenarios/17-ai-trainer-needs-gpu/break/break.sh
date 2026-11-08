#!/usr/bin/env bash
# K17 break: an "AI trainer" requires a node labelled accelerator=nvidia-gpu, which no node has.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-17-needs-gpu"

# The intended failure: the Pod exists, the scheduler refused it, and an event says why.
refused() {
  kubectl get pods -n "$NS" -l app=trainer --no-headers 2>/dev/null | grep -q ' Pending ' &&
    kubectl get events -n "$NS" 2>/dev/null | grep -q 'FailedScheduling'
}

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Starting the AI trainer…"
kubectl apply -f "$HERE/" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the scheduler to refuse the trainer" 60 refused \
  || die "The trainer never showed up as Pending. Run cleanup.sh and try again."

show_next \
  "Your AI trainer is deployed and the nodes are up, but the training never starts. There is no web page: it's all in the terminal." \
  "kubectl get pods -n $NS"
