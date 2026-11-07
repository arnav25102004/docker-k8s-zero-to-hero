#!/usr/bin/env bash
# 🔥 Troubleshooting scenario runner for docker-k8s-zero-to-hero
#
#   ./labs.sh                     interactive menu
#   ./labs.sh git 02              break Git scenario G-02 (sandbox in /tmp/z2h-git-ts)
#   ./labs.sh git 02 fix
#   ./labs.sh k8s 04              break Kubernetes scenario K-04
#   ./labs.sh k8s 04 fix
#   ./labs.sh docker clean        run every docker/scenarios/*/cleanup.sh
#   (Docker scenarios are run by hand: see docker/scenarios/README.md)
#   ./labs.sh k8s clean           delete the troubleshoot namespaces
#   ./labs.sh list
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GITTS_DIR="$ROOT/git/troubleshooting"
DOCKER_DIR="$ROOT/docker/scenarios"
K8S_DIR="$ROOT/kubernetes/troubleshooting"
NS=troubleshoot

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
die()   { printf '\033[1;31m✖ %s\033[0m\n' "$*"; exit 1; }

title_of() {   # git/k8s: description.md, docker: README.md (first line, without "# ")
  local f="$1/description.md"
  [ -f "$f" ] || f="$1/README.md"
  head -1 "$f" | sed 's/^# //'
}

scenario_dir() {   # $1 = git|docker|k8s, $2 = number
  local base
  case "$1" in git) base="$GITTS_DIR" ;; *) base="$K8S_DIR" ;; esac
  local n; n=$(printf '%02d' "$((10#$2))")
  local d; d=$(ls -d "$base/$n"-*/ 2>/dev/null | head -1)
  [ -n "$d" ] || die "No $1 scenario number $2. Try: ./labs.sh list"
  echo "${d%/}"
}

list() {
  bold "🌿 Git scenarios"
  for d in "$GITTS_DIR"/[0-9]*/; do printf '  %s\n' "$(title_of "$d")"; done
  echo
  bold "🐳 Docker scenarios (run them by hand: docker/scenarios/README.md)"
  for d in "$DOCKER_DIR"/[0-9]*/; do printf '  %s\n' "$(title_of "$d")"; done
  echo
  bold "☸️  Kubernetes scenarios"
  for d in "$K8S_DIR"/[0-9]*/; do printf '  %s\n' "$(title_of "$d")"; done
}

# ------------------------------------------------------------------- git --
git_break() {
  info "Breaking: $(title_of "$1")"
  bash "$1/break.sh"
  echo
  bold "📖 Read the story and investigate:  $1/description.md"
  echo "   Sandbox: /tmp/z2h-git-ts/$(basename "$1")   ·   start with: git status · git log --oneline --graph --all"
}
git_fix()   { info "Applying the reference fix for: $(title_of "$1")"; bash "$1/fix.sh"; }
git_clean() { rm -rf "${Z2H_GIT_TS:-/tmp/z2h-git-ts}"; ok "Git scenario sandboxes removed"; }

# ---------------------------------------------------------------- docker --
docker_clean() {
  local c
  for c in "$DOCKER_DIR"/[0-9]*/cleanup.sh; do
    [ -f "$c" ] && bash "$c" >/dev/null 2>&1
  done
  ok "Docker scenario resources removed"
}

# ------------------------------------------------------------------- k8s --
k8s_preflight() {
  command -v kubectl >/dev/null || die "kubectl not found"
  kubectl cluster-info >/dev/null 2>&1 || die "Cannot reach a cluster. Check: kubectl config current-context"
  if grep -q 'z2h/api' "$1"/*.yaml 2>/dev/null; then
    warn "This scenario uses the course image z2h/api:1.0. If Pods show ErrImageNeverPull/ImagePullBackOff"
    warn "for z2h/api:1.0 itself, load it first: ./scripts/load-image.sh z2h/api:1.0"
  fi
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

k8s_break() {
  local d=$1
  k8s_preflight "$d"
  kubectl delete -f "$d/issue.yaml" --ignore-not-found --wait=true >/dev/null 2>&1
  [ -f "$d/fix.yaml" ] && kubectl delete -f "$d/fix.yaml" --ignore-not-found --wait=true >/dev/null 2>&1
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  info "Breaking: $(title_of "$d")"
  if [ -f "$d/break.sh" ]; then bash "$d/break.sh"; else kubectl apply -f "$d/issue.yaml"; fi
  info "Letting the problem show itself (15s)..."
  sleep 15
  kubectl get pods,svc,pvc -n "$NS" 2>/dev/null
  echo
  bold "📖 Read the story and investigate:  $d/description.md"
  echo "   Start with:  kubectl get pods -n $NS   ·   kubectl describe pod -n $NS <name>   ·   kubectl get events -n $NS --sort-by=.metadata.creationTimestamp"
}

k8s_fix() {
  local d=$1
  info "Applying the reference fix for: $(title_of "$d")"
  if [ -f "$d/fix.sh" ]; then
    bash "$d/fix.sh"
  elif ! kubectl apply -f "$d/fix.yaml" 2>/tmp/z2h-fix.err; then
    warn "Some fields are immutable; recreating the resources instead"
    kubectl delete -f "$d/issue.yaml" --ignore-not-found --wait=true >/dev/null 2>&1
    kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    kubectl apply -f "$d/fix.yaml"
  fi
  info "Waiting for things to settle (20s)..."
  sleep 20
  kubectl get pods -n "$NS"
  if kubectl get pod ts-client -n "$NS" >/dev/null 2>&1; then
    echo; info "What the user sees now:"; kubectl logs ts-client -n "$NS" --tail=3
  fi
}

k8s_clean() {
  kubectl delete namespace "$NS" ts-backend --ignore-not-found --wait=false
  ok "Kubernetes scenario namespaces are being deleted"
}

# ----------------------------------------------------------- interactive --
menu() {
  clear 2>/dev/null || true
  bold "🔥 Troubleshooting Arena: break it, find it, fix it"
  echo
  local i=1 entries=()
  for d in "$GITTS_DIR"/[0-9]*/;  do entries+=("git:${d%/}");    printf '  %2d) 🌿 %s\n' $i "$(title_of "$d")"; i=$((i+1)); done
  for d in "$K8S_DIR"/[0-9]*/;   do entries+=("k8s:${d%/}");    printf '  %2d) ☸️  %s\n' $i "$(title_of "$d")"; i=$((i+1)); done
  echo
  echo "  🐳 Docker scenarios: open docker/scenarios/README.md (run by hand)"
  echo "   c) clean up everything      q) quit"
  echo
  read -r -p "Pick a scenario: " choice
  case "$choice" in
    q|Q) exit 0 ;;
    c|C) git_clean; docker_clean; kubectl cluster-info >/dev/null 2>&1 && k8s_clean; exit 0 ;;
  esac
  [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#entries[@]} ] || die "Invalid choice"
  local kind=${entries[$((choice-1))]%%:*} dir=${entries[$((choice-1))]#*:}
  "${kind}_break" "$dir"
  echo
  read -r -p "🔍 Investigate in another terminal. Press Enter when you want to see the fix... "
  echo; bold "──────── The fix ────────"
  if [ -f "$dir/fix.sh" ]; then cat "$dir/fix.sh"; else cat "$dir/fix.yaml"; fi
  echo; read -r -p "Apply it? [Y/n] " yn
  [[ "$yn" =~ ^[Nn] ]] || "${kind}_fix" "$dir"
  echo; read -r -p "Clean up this scenario now? [Y/n] " yn
  [[ "$yn" =~ ^[Nn] ]] || "${kind}_clean"
}

# ------------------------------------------------------------------ main --
case "${1:-}" in
  "") menu ;;
  list) list ;;
  docker)
    case "${2:-}" in
      clean) docker_clean ;;
      *) echo "Docker scenarios are run by hand. Open docker/scenarios/README.md"
         echo "Reset everything with: ./labs.sh docker clean" ;;
    esac ;;
  git|k8s)
    kind=$1
    case "${2:-}" in
      clean) "${kind}_clean" ;;
      ""|help) list ;;
      *) d=$(scenario_dir "$kind" "$2"); if [ "${3:-}" = fix ]; then "${kind}_fix" "$d"; else "${kind}_break" "$d"; fi ;;
    esac ;;
  *) sed -n '2,12p' "$0" ;;
esac
