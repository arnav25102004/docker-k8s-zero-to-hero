#!/usr/bin/env bash
# Removes everything scenario K16 created, including the z2h-vip taint on the nodes.
# Safe to run any time, any number of times (also after an interrupted break.sh).
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
if ! kubectl get --raw /readyz >/dev/null 2>&1; then
  warn "Can't reach the cluster: nothing to clean up."
  exit 0
fi
# Untaint FIRST: if anything below were interrupted, the nodes must not stay reserved,
# or every other scenario's Pods would go Pending.
untaint_all z2h-vip
scenario_k8s_cleanup k-16-vip-node
