#!/usr/bin/env bash
# Am I done? Run this any time. It only looks around; it never changes anything (and it does
# not send the robot: run ./evict.sh yourself for that).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../_lib.sh"

NS="k-39-idli-robot"
need_cluster
allowed=$(kubectl get pdb idli-pdb -n "$NS" -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)
healthy=$(kubectl get pdb idli-pdb -n "$NS" -o jsonpath='{.status.currentHealthy}' 2>/dev/null)
if [ "${allowed:-0}" -ge 1 ] && [ "${healthy:-0}" -ge 2 ]; then
  ok "The safety rule now lets $allowed Pod(s) move at a time, while still guarding the stall."
  exit 0
fi
warn "Not yet: the rule allows ${allowed:-0} Pod(s) to be away right now, with ${healthy:-0} healthy. The robot will keep being refused."
exit 1
