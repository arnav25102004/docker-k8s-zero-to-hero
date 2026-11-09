#!/usr/bin/env bash
# Removes everything scenario K25 created, including metrics-server if (and only if) we installed it.
# Safe to run any time, any number of times.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
if ! kubectl get --raw /readyz >/dev/null 2>&1; then
  warn "Can't reach the cluster: nothing to clean up."
  exit 0
fi
# Namespace first, then the add-on, so an interrupted run never leaves either behind.
scenario_k8s_cleanup k-25-hpa
remove_metrics_server_if_ours k25
