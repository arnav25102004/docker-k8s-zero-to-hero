#!/usr/bin/env bash
# Removes everything scenario K26 created. Safe to run any time, any number of times.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
if ! kubectl get --raw /readyz >/dev/null 2>&1; then
  warn "Can't reach the cluster: nothing to clean up."
  exit 0
fi
scenario_k8s_cleanup k-26-init-stuck
