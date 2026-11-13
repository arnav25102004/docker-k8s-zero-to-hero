#!/usr/bin/env bash
# S4.4 fix: give the bot's ServiceAccount a Role (get, list on pods) through a RoleBinding.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-14-forbidden"

# The bot's newest log line is a ✅ line (it runs every 5 s; no restart needed).
bot_ok() { kubectl logs bot -n "$NS" --tail=1 2>/dev/null | grep -q "✅"; }

need_cluster
say "Granting the bot permission to read Pods (Role + RoleBinding)…"
kubectl apply -f "$HERE/rbac.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the bot to read the Pods (✅)" 60 bot_ok \
  || die "The bot still isn't succeeding. Check: kubectl logs bot -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl logs bot -n $NS --tail=3" \
  "kubectl auth can-i list pods -n $NS --as=system:serviceaccount:$NS:leaderboard-bot"
