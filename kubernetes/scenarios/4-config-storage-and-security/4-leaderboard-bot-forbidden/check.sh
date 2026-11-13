#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-14-forbidden"
need_cluster
if kubectl logs bot -n "$NS" --tail=1 2>/dev/null | grep -q "✅"; then
  ok "The bot is allowed to read the Pods: its latest line is ✅."
  exit 0
fi
warn "Not yet: the bot's latest line is not ✅. Check: kubectl logs bot -n $NS --tail=3"
exit 1
