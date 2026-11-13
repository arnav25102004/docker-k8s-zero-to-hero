#!/usr/bin/env bash
# The nightly maintenance robot. It asks Kubernetes, politely, to move ONE idli Pod somewhere
# else: the same "eviction" request that `kubectl drain` sends for every Pod on a node.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-39-idli-robot"
need_cluster
POD=$(kubectl get pods -n "$NS" -l app=idli -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$POD" ] || die "No idli Pod found. Run ./break/break.sh first."

printf '🤖 Maintenance robot: asking Kubernetes to move %s…\n' "$POD"
if out=$(printf '{"apiVersion":"policy/v1","kind":"Eviction","metadata":{"name":"%s","namespace":"%s"}}' "$POD" "$NS" \
    | kubectl create --raw "/api/v1/namespaces/$NS/pods/$POD/eviction" -f - 2>&1); then
  ok "The robot moved $POD. Kubernetes opened a replacement straight away."
  exit 0
fi
printf '\033[1;31m✖ The robot was refused:\033[0m\n'
printf '%s\n' "$out" | sed 's/^/   /'
exit 1
