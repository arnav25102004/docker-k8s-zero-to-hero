#!/usr/bin/env bash
# S1.5 fix: the leftover finalizer is removed, so the pending delete can finish.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-37-stuck-pod"

pod_gone() { ! kubectl get pod old-stall -n "$NS" >/dev/null 2>&1; }

need_cluster
say "Removing the finalizer nobody is going to honour…"
kubectl patch pod old-stall -n "$NS" --type merge -p '{"metadata":{"finalizers":null}}' >/dev/null \
  || die "kubectl patch failed. Is the Pod still there? Check: kubectl get pods -n $NS"

wait_for "the Pod to disappear" 60 pod_gone \
  || die "The Pod is still there. Check: kubectl get pod old-stall -n $NS -o yaml"

show_next "✅ Fixed. The Pod is gone. Check it yourself:" \
  "./check.sh   ·   kubectl get pods -n k-37-stuck-pod"
