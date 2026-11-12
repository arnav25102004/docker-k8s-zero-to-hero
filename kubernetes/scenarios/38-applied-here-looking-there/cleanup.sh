#!/usr/bin/env bash
# Removes everything scenario K38 created. Safe to run any time, any number of times.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
if ! kubectl get --raw /readyz >/dev/null 2>&1; then
  warn "Can't reach the cluster: nothing to clean up."
  exit 0
fi
# Put your context's namespace back only if this scenario was the one that changed it.
if [ "$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)" = "k-38-night-canteen" ]; then
  kubectl config set-context --current --namespace="" >/dev/null 2>&1
fi
scenario_k8s_cleanup k-38-night-canteen
