#!/usr/bin/env bash
# S4.2 fix: create the missing Secret. The kubelet retries on its own, so the existing Pod starts.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-09-missing-secret"

# NOT "rollout status": no new ReplicaSet is created, the SAME Pod just starts. Check the Pod itself.
pod_ready() { [ "$(kubectl get pod -n "$NS" -l app=adminer -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]; }

need_cluster
say "Creating the missing Secret adminer-db…"
kubectl apply -f "$HERE/secret.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the Adminer Pod to start by itself (the kubelet retries)" 180 pod_ready \
  || die "The Pod didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/adminer 9209:80   (in a second terminal; then open http://localhost:9209; on a playground add --address 0.0.0.0 and open the URL for port 9209)"
