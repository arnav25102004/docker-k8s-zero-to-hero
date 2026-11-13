#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-48-ramp"
need_cluster
if ! check_rollouts "$NS"; then
  warn "Not yet. The cache is not Ready."
  exit 1
fi
max=$(kubectl get deployment cache -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="CACHE_MAX_MB")].value}' 2>/dev/null)
oom=$(kubectl get pods -n "$NS" -l app=cache --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
if [ "${max:-0}" -gt 0 ] 2>/dev/null && [ "${max:-0}" -lt 80 ] 2>/dev/null && [ "$oom" != "OOMKilled" ]; then
  ok "The cache is bounded at ${max} MB, safely under its 96 MB limit, and the newest Pod has not been OOM-killed."
  exit 0
fi
warn "Not yet: the cache ceiling is '${max:-none}' MB and the newest Pod's last end was '${oom:-none}'. A ceiling of 0 means no ceiling; it must stay well below the 96 MB limit."
exit 1
