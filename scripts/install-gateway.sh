#!/usr/bin/env bash
# Install a Gateway API controller (Envoy Gateway) and a GatewayClass called "eg".
# Lab K12 teaches it; scenario K33 needs it. Safe to run again.
#
#   ./scripts/install-gateway.sh
#
# Needs: kubectl, a cluster with about 1 GB of free memory.
set -euo pipefail

VERSION="v1.9.3"                 # one place to change when you want a newer release
URL="https://github.com/envoyproxy/gateway/releases/download/${VERSION}/install.yaml"

say()  { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✖ %s\033[0m\n' "$*"; exit 1; }

command -v kubectl >/dev/null 2>&1 || die "kubectl isn't installed. See 00-setup."
kubectl get --raw /readyz >/dev/null 2>&1 || die "Can't reach a cluster. Check: kubectl config current-context"

say "Installing Envoy Gateway ${VERSION} (this also installs the Gateway API types)"
kubectl apply --server-side -f "$URL" >/dev/null || die "Could not download ${URL}. Check your connection, then run this again."
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available >/dev/null \
  || die "Envoy Gateway did not become ready. Look: kubectl get pods -n envoy-gateway-system"

say "Creating the GatewayClass \"eg\""
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
ok "Envoy Gateway is ready. Gateways that use gatewayClassName: eg will be served."
