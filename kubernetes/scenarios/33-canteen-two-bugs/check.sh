#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-33-canteen"
need_cluster
addrs=$(kubectl get endpointslices -n "$NS" -l kubernetes.io/service-name=canteen -o jsonpath='{..addresses}' 2>/dev/null)
if [ -z "$addrs" ]; then
  warn "Not yet: the canteen Service still has no endpoints."
  exit 1
fi
if kubectl logs visitor -n "$NS" --tail=2 2>/dev/null | grep -q "✅"; then
  ok "Lemon rice is being served. Both bugs are gone."
  exit 0
fi
warn "Endpoints exist now, but the visitor still isn't being served. Is there a second problem? Give it a few seconds and run this again."
exit 1
