#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-46-3am"
need_cluster
if check_rollouts "$NS" && check_visitor "$NS"; then
  ok "The orders service is up and the visitor sees ✅. (The alert clears on its own a few minutes after the restarts stop.)"
  exit 0
fi
warn "Not yet. The service is not stable yet; give a restart a few seconds, then run ./check.sh again."
exit 1
