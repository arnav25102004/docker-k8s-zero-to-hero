#!/usr/bin/env bash
# K27 fix: correct the ConfigMap, then restart the Deployment. The stuck Pod would also start by itself
# (the kubelet retries the volume setup), but its pauses grow up to about 2 minutes: restart = no dead air.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-27-config-key"

need_cluster
say "Correcting the ConfigMap…"
kubectl apply -f "$HERE/links.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

# A new Pod starts right now, instead of waiting for the kubelet's next retry.
say "Restarting the dashboard so it picks up the corrected ConfigMap…"
kubectl rollout restart deployment/dashboard -n "$NS" >/dev/null || die "kubectl rollout restart failed. Is the scenario running? Try break.sh first."
say "Waiting for the dashboard (the first start also downloads Homer, about 7 MB)…"
kubectl rollout status deployment/dashboard -n "$NS" --timeout=180s >/dev/null \
  || die "The dashboard didn't become Ready. Check: kubectl get pods -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/dashboard 9227:80   (in a second terminal; then open http://localhost:9227; on a playground add --address 0.0.0.0 and open the URL for port 9227)"
