#!/usr/bin/env bash
# Removes everything scenario K37 created. Safe to run any time, any number of times.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
if ! kubectl get --raw /readyz >/dev/null 2>&1; then
  warn "Can't reach the cluster: nothing to clean up."
  exit 0
fi
# A finalizer keeps a Pod (and its namespace) from being deleted, so lift it first.
kubectl patch pod old-stall -n k-37-stuck-pod --type merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1
scenario_k8s_cleanup k-37-stuck-pod
