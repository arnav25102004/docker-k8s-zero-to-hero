#!/usr/bin/env bash
# Pre-flight check for docker-k8s-zero-to-hero. Run it the day BEFORE class.
#
#   ./scripts/check-prereqs.sh          check tools, engine, cluster, resources
#   ./scripts/check-prereqs.sh --pull   ...and pre-pull every image the labs use
set -uo pipefail

pass=0; fail=0
ok()   { printf '  \033[1;32m✔\033[0m %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  \033[1;31m✖\033[0m %s\n' "$*"; fail=$((fail+1)); }
note() { printf '  \033[1;33m•\033[0m %s\n' "$*"; }
head1(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

IMAGES=(
  hello-world busybox:1.36 alpine ubuntu:24.04
  nginx:1.27-alpine nginxinc/nginx-unprivileged:1.27-alpine
  python:3.12-alpine redis:7-alpine postgres:16-alpine registry:2
  golang:1.23 gcr.io/distroless/static-debian12:nonroot
  nicolaka/netshoot curlimages/curl:8.11.1
  docker/welcome-to-docker nginxdemos/hello
  pengbai/docker-supermario wernight/funbox
  # D01 student survival kit (Stirling-PDF is left out on purpose: ~1 GB, optional bonus)
  codercom/code-server:latest quay.io/jupyter/base-notebook:latest
  excalidraw/excalidraw:latest corentinth/it-tools:latest
  # Docker break/fix scenarios (exact pins; the full list is docker/scenarios/IMAGES.md)
  quay.io/jupyter/base-notebook:2026-11-02 codercom/code-server:4.145.2
  excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9
  corentinth/it-tools:2024.10.22-7ca5933
  redis:7.4.12-alpine nginx:1.27.5-alpine postgres:16.15-alpine
  # Kubernetes break/fix scenarios (exact pins; the full list is kubernetes/scenarios/IMAGES.md)
  kanboard/kanboard:v1.2.57 adminer:5.4.1
  traefik/whoami:v1.10.4 b4bz/homer:v25.10.1 nginxinc/nginx-unprivileged:1.27.5-alpine
  registry.k8s.io/metrics-server/metrics-server:v0.9.1
)

head1 "🧰 Tools"
if command -v docker >/dev/null; then ok "docker CLI $(docker version --format '{{.Client.Version}}' 2>/dev/null)"; else bad "docker CLI not found → 00-setup"; fi
if docker compose version >/dev/null 2>&1; then ok "docker compose $(docker compose version --short 2>/dev/null)"; else bad "docker compose not found (the Compose v2 plugin: update Docker Desktop, or install docker-compose-plugin) → 00-setup"; fi
if command -v kubectl >/dev/null; then ok "kubectl $(kubectl version --client -o json 2>/dev/null | grep -m1 gitVersion | cut -d'"' -f4)"; else bad "kubectl not found → 00-setup"; fi
command -v git  >/dev/null && ok "git"  || note "git not found (only needed to clone the repo)"
command -v curl >/dev/null && ok "curl" || bad "curl not found"

head1 "🐳 Docker engine"
if docker info >/dev/null 2>&1; then
  ok "engine running: $(docker info --format '{{.ServerVersion}} on {{.OperatingSystem}}')"
  cpus=$(docker info --format '{{.NCPU}}'); mem=$(( $(docker info --format '{{.MemTotal}}') / 1024 / 1024 / 1024 ))
  [ "$cpus" -ge 4 ] && ok "$cpus CPUs" || note "$cpus CPUs (4+ recommended)"
  [ "$mem" -ge 6 ] && ok "${mem} GB memory" || note "${mem} GB memory for Docker (6+ recommended: Docker Desktop → Settings → Resources)"
  docker run --rm hello-world >/dev/null 2>&1 && ok "can run containers" || bad "docker run hello-world failed"
else
  bad "engine not reachable: start Docker Desktop (or: sudo systemctl start docker)"
fi

head1 "☸️  Kubernetes"
if kubectl cluster-info >/dev/null 2>&1; then
  ok "context: $(kubectl config current-context)"
  ok "nodes: $(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1"("$2")"}' | tr '\n' ' ')"
  kubectl get storageclass 2>/dev/null | grep -q default && ok "default StorageClass present" || note "no default StorageClass (needed for K10/K18)"
  kubectl top nodes >/dev/null 2>&1 && ok "metrics-server working" || note "metrics-server not installed: run ./scripts/install-metrics-server.sh (K01 and K13 use it)"
  if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then ok "Gateway API CRDs present"; else note "Gateway API not installed (installed in Lab K12)"; fi
else
  note "no cluster reachable: fine for the Docker labs; needed from Lab K01 (see 00-setup)"
fi

head1 "📦 Course images"
for img in z2h/api:1.0 z2h/frontend:1.0; do
  docker image inspect "$img" >/dev/null 2>&1 && ok "$img built" || note "$img not built yet: docker build -t $img apps/${img#z2h/}"
done

if [ "${1:-}" = "--pull" ]; then
  head1 "⬇️  Pre-pulling lab images (grab a coffee ☕)"
  for img in "${IMAGES[@]}"; do
    if docker pull -q "$img" >/dev/null 2>&1; then ok "$img"; else bad "$img"; fi
  done
  docker build -q -t z2h/api:1.0 "$(dirname "$0")/../apps/api" >/dev/null && ok "built z2h/api:1.0"
  docker build -q -t z2h/frontend:1.0 "$(dirname "$0")/../apps/frontend" >/dev/null && ok "built z2h/frontend:1.0"
else
  note "run with --pull to pre-download all ${#IMAGES[@]} lab images"
fi

printf '\n\033[1m%s passed, %s failed\033[0m\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && printf '🚀 You are ready for showtime!\n' || exit 1
