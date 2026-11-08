#!/usr/bin/env bash
# Spec for scenario K14 (14-leaderboard-bot-forbidden). Sourced by tests/scenarios/k8s.sh.
# shellcheck disable=SC2034  # read by tests/scenarios/k8s.sh
NAMESPACES="k-14-forbidden"

SA="system:serviceaccount:k-14-forbidden:leaderboard-bot"

# bot_ok: the bot's latest log line is a ✅ line.
bot_ok() { kubectl logs bot -n k-14-forbidden --tail=1 2>/dev/null | grep -q "✅"; }

broken() {
  assert_contains "$(kubectl logs bot -n k-14-forbidden 2>&1)" "403" "bot logs contain 403"
  assert_eq "$(kubectl auth can-i list pods -n k-14-forbidden --as=$SA 2>&1)" "no" "can-i list pods is no"
}

fixed() {
  assert_eq "$(kubectl auth can-i list pods -n k-14-forbidden --as=$SA 2>&1)" "yes" "can-i list pods is yes"
  local i=0
  while [ "$i" -lt 15 ] && ! bot_ok; do sleep 1; i=$((i + 1)); done
  bot_ok
  assert_eq "$?" "0" "bot logs show ✅ within 15 s"
}
