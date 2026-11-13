#!/usr/bin/env bash
# Install metrics-server once, right after the cluster is up, so `kubectl top` works from the
# first lab. Safe to run again: it does nothing if metrics already work.
#
#   ./scripts/install-metrics-server.sh
#
# Docker Desktop, kind, Killercoda and any plain cluster: installs the pinned upstream release.
# minikube: turns on its built-in addon instead.
set -euo pipefail

VERSION="v0.9.1"
URL="https://github.com/kubernetes-sigs/metrics-server/releases/download/${VERSION}/components.yaml"

say()  { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✖ %s\033[0m\n' "$*"; exit 1; }

command -v kubectl >/dev/null 2>&1 || die "kubectl isn't installed. See 00-setup."
kubectl get --raw /readyz >/dev/null 2>&1 || die "Can't reach a cluster. Check: kubectl config current-context"

metrics_work() { kubectl top nodes >/dev/null 2>&1; }

if metrics_work; then
  ok "metrics-server already works (kubectl top nodes answers). Nothing to do."
  exit 0
fi

CTX="$(kubectl config current-context 2>/dev/null || true)"
if [ "$CTX" = "minikube" ] && command -v minikube >/dev/null 2>&1; then
  say "minikube: enabling its metrics-server addon"
  minikube addons enable metrics-server >/dev/null
elif kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  say "metrics-server is already installed; waiting for it to become ready"
else
  say "Installing metrics-server ${VERSION}"
  kubectl apply -f "$URL" >/dev/null || die "Could not download ${URL}. Check your connection, then run this again."
  # Local clusters use self-signed kubelet certificates. Fine for a lab, never for production.
  if ! kubectl get deployment metrics-server -n kube-system -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q 'kubelet-insecure-tls'; then
    kubectl patch deployment metrics-server -n kube-system --type=json \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null
  fi
fi

kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s >/dev/null 2>&1 \
  || die "metrics-server did not become ready. Look: kubectl -n kube-system get pods -l k8s-app=metrics-server"

say "Waiting for the first numbers (metrics-server needs about a minute to collect them)"
for _ in $(seq 1 40); do
  if metrics_work; then
    ok "metrics-server works. Try: kubectl top nodes"
    exit 0
  fi
  sleep 3
done
die "metrics-server is running but has no numbers yet. Wait a minute and try: kubectl top nodes"
