#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-38-night-canteen"
need_cluster
now=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
now=${now:-default}
if [ "$now" = "$NS" ]; then
  ok "Your kubectl now looks in $NS. A plain 'kubectl get pods' shows the night canteen."
  exit 0
fi
warn "Not yet: a plain 'kubectl' command still goes to the namespace '$now', not to the one the night canteen lives in."
exit 1
