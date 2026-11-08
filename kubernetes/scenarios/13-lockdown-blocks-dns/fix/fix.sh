#!/usr/bin/env bash
# K13 fix: add the missing DNS rule to the lockdown policy (a policy can be changed in place).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-13-lockdown"

need_cluster
say "Letting the app talk to DNS (port 53 in kube-system)…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Checking the app rolled out…"
kubectl rollout status deployment/showdown -n "$NS" --timeout=180s >/dev/null \
  || die "The app didn't roll out. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get networkpolicy lockdown -n $NS -o yaml" \
  "kubectl port-forward -n $NS svc/showdown 9213:80   (in a second terminal; then open http://localhost:9213; on a playground add --address 0.0.0.0 and open the URL for port 9213)"
