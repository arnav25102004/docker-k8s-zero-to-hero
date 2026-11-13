#!/usr/bin/env bash
# S6.1 fix: the current context now points at the namespace the canteen lives in.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../../_lib.sh"

NS="k-38-night-canteen"

need_cluster
say "Pointing your current context at the namespace $NS…"
kubectl config set-context --current --namespace="$NS" >/dev/null \
  || die "Could not change the current context. Check: kubectl config get-contexts"

show_next "✅ Done. A plain 'kubectl get pods' now looks in $NS. Check it yourself:" \
  "./check.sh   ·   kubectl get pods   ·   (to undo later: ./cleanup.sh)"
