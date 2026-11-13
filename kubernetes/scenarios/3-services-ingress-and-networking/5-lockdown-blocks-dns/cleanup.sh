#!/usr/bin/env bash
# Removes everything scenario S3.5 created (including the throwaway probe namespace). Safe to run any time.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/../.." && pwd)/_lib.sh"
if ! kubectl get --raw /readyz >/dev/null 2>&1; then
  warn "Can't reach the cluster: nothing to clean up."
  exit 0
fi
scenario_k8s_cleanup k-13-lockdown k-13-probe
