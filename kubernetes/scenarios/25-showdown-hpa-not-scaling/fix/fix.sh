#!/usr/bin/env bash
# K25 fix: the same Deployment, now with a CPU request of 100m and a limit of 200m.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

NS="k-25-hpa"

# A number (not <unknown>) in the CPU reading, and more than one replica.
scaled_up() {
  local util cur
  util=$(kubectl get hpa showdown -n "$NS" -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
  cur=$(kubectl get hpa showdown -n "$NS" -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
  [ -n "$util" ] && [ "${cur:-1}" -ge 2 ]
}

need_cluster
say "Telling Kubernetes how much CPU the app asks for (request 100m, limit 200m)…"
kubectl apply -f "$HERE/app.yaml" >/dev/null || die "kubectl apply failed. Is the cluster healthy?"

kubectl rollout status deployment/showdown -n "$NS" --timeout=180s \
  || die "The app didn't become Ready. Check: kubectl get pods -n $NS"

say "The first CPU readings take about a minute, then the autoscaler checks every ~15 seconds."
wait_for "the autoscaler to read CPU and add a replica" 240 scaled_up \
  || die "No scale-up within 240s. Check: kubectl get hpa -n $NS"

show_next "✅ Fixed. Now verify it yourself:" \
  "kubectl get hpa -n $NS" \
  "kubectl get pods -n $NS" \
  "kubectl port-forward -n $NS svc/showdown 9225:80   (in a second terminal; then open http://localhost:9225; on a playground add --address 0.0.0.0 and open the URL for port 9225)"
