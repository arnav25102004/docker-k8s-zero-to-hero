#!/usr/bin/env bash
# K27 fix: correct the ConfigMap. The stuck Pod does not need a restart: the kubelet keeps retrying
# the failed volume setup (with growing pauses, up to about 2 minutes), so the Pod starts by itself.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-27-config-key"

need_cluster
say "Correcting the ConfigMap…"
kubectl apply -f "$HERE/links.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

say "Waiting for the dashboard (the kubelet retries the stuck Pod on its own; the first start also downloads Homer, about 7 MB)…"
kubectl rollout status deployment/dashboard -n "$NS" --timeout=180s >/dev/null \
  || die "The dashboard didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/dashboard 9227:80   (in a second terminal; then open http://localhost:9227; on a playground add --address 0.0.0.0 and open the URL for port 9227)"
