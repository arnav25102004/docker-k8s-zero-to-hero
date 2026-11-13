#!/usr/bin/env bash
# Remove Prometheus + Grafana (installed by install-monitoring.sh), including the CRDs the chart adds.
set -u
command -v helm >/dev/null 2>&1 || { echo "helm isn't installed, so nothing was installed with it." >&2; exit 0; }
helm uninstall kube-prometheus-stack -n monitoring >/dev/null 2>&1 && echo "✔ release removed" || echo "(no release found)"
kubectl delete namespace monitoring --ignore-not-found --wait=false >/dev/null 2>&1
# Helm never deletes CRDs, so remove the ones the chart created.
for crd in $(kubectl get crd -o name 2>/dev/null | grep 'monitoring.coreos.com'); do kubectl delete "$crd" >/dev/null 2>&1 || true; done
echo "✔ monitoring removed (metrics-server is left in place)"
