#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-42-qos"
need_cluster
# the class of the NEWEST Pod of a workload (an old Pod can linger while it is replaced)
qos_of() { kubectl get pods -n "$NS" -l app="$1" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].status.qosClass}' 2>/dev/null; }
want_cache=Guaranteed; want_web=Burstable; want_batch=BestEffort
good=0
for d in cache web batch; do
  want=$(eval echo \$want_$d)
  got=$(qos_of $d)
  if [ "$got" = "$want" ]; then
    printf '  ✅ %-6s is %s, as it should be\n' "$d" "$got"
    good=$((good + 1))
  else
    printf '  ❌ %-6s is %s, but should be %s\n' "$d" "${got:-unknown}" "$want"
  fi
done
if [ "$good" -eq 3 ]; then
  ok "Every workload is in the right class. Under memory pressure the batch job goes first, the cache last."
  exit 0
fi
warn "Not yet: $good of 3 are right. (A changed Deployment replaces its Pod, so give it a few seconds.)"
exit 1
