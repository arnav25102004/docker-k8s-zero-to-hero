#!/usr/bin/env bash
# S4.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-14-forbidden"

# The bot has asked the API at least once and been told 403.
forbidden() { kubectl logs bot -n "$NS" 2>/dev/null | grep -q "403"; }
players_up() { kubectl rollout status deployment/players -n "$NS" --timeout=2s >/dev/null 2>&1; }

need_cluster
bash "$HERE/../cleanup.sh"
fresh_ns "$NS" || die "Could not create the namespace $NS."

say "Deploying the leaderboard bot and two players…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

wait_for "the players to start" 180 players_up \
  || die "The players didn't start. Run cleanup.sh and try again."

wait_for "the bot to be refused by the API (403)" 180 forbidden \
  || die "Expected the bot to be refused, but didn't see it. Run cleanup.sh and try again."

scene_set
