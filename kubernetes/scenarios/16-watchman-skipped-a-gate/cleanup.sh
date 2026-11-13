#!/usr/bin/env bash
# Removes everything scenario K16 created. Safe to run any time, any number of times.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
if ! kubectl get --raw /readyz >/dev/null 2>&1; then
  warn "Can't reach the cluster: nothing to clean up."
  exit 0
fi
# Remove the "reserved" sign first: if anything below were interrupted, the node must not stay reserved.
untaint_all z2h-vip
scenario_k8s_cleanup k-16-daemonset
