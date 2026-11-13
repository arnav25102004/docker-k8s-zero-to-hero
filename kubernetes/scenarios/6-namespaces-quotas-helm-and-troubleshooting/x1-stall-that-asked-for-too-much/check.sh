#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-40-limit-max"
need_cluster
if [ "$(kubectl get limitrange stall-limits -n "$NS" -o jsonpath='{.spec.limits[0].max.memory}' 2>/dev/null)" != "128Mi" ]; then
  warn "The kitchen rule (LimitRange stall-limits, max 128Mi) was changed or removed. Deleting the rule is not a fix: put it back and shrink the request instead."
  exit 1
fi
ready=$(kubectl get deployment chaat -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
ready=${ready:-0}
if [ "$ready" -ge 2 ]; then
  ok "The chaat stall is open: both Pods were admitted and are Ready."
  exit 0
fi
warn "Not yet: $ready of 2 Pods are Ready. The ReplicaSet can only create Pods the namespace accepts."
exit 1
