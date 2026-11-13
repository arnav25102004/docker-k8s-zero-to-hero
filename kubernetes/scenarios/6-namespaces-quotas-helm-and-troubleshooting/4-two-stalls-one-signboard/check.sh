#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-31-two-stalls"
need_cluster
names=$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=chai -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}{"\n"}{end}' 2>/dev/null)
fresh=$(printf '%s\n' "$names" | grep -c '^chai-')
stale=$(printf '%s\n' "$names" | grep -c '^stale-chai-')

if [ "$stale" -eq 0 ] && [ "$fresh" -ge 2 ]; then
  ok "Every customer now gets fresh chai ($fresh fresh addresses, 0 stale). The signboard is honest again."
  exit 0
fi
[ "$stale" -gt 0 ] && warn "Not yet: $stale of the Service's addresses still point at the stale stall."
[ "$fresh" -lt 2 ] && warn "Careful: only $fresh fresh address(es) behind the Service. You want both fresh Pods in."
exit 1
