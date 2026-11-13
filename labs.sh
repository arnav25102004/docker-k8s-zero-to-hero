#!/usr/bin/env bash
# 🔥 Troubleshooting scenario runner for docker-k8s-zero-to-hero
#
#   ./labs.sh                     interactive menu
#   ./labs.sh git 02              break Git scenario G-02 (sandbox in /tmp/z2h-git-ts)
#   ./labs.sh git 02 fix
#   ./labs.sh docker clean        run every docker/scenarios/*/cleanup.sh
#   ./labs.sh k8s clean           run every Kubernetes scenario's cleanup.py
#   (Docker and Kubernetes scenarios are run by hand: see
#    docker/scenarios/README.md and kubernetes/scenarios/README.md)
#   ./labs.sh list
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GITTS_DIR="$ROOT/git/troubleshooting"
DOCKER_DIR="$ROOT/docker/scenarios"
K8S_DIR="$ROOT/kubernetes/scenarios"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
die()   { printf '\033[1;31m✖ %s\033[0m\n' "$*"; exit 1; }

title_of() {   # git: description.md, docker/k8s: README.md (first line, without "# ")
  local f="$1/description.md"
  [ -f "$f" ] || f="$1/README.md"
  head -1 "$f" | sed 's/^# //'
}

scenario_dir() {   # $1 = git, $2 = number
  local n; n=$(printf '%02d' "$((10#$2))")
  local d; d=$(ls -d "$GITTS_DIR/$n"-*/ 2>/dev/null | head -1)
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
  bold "☸️  Kubernetes scenarios (run them by hand: kubernetes/scenarios/README.md)"
  for d in "$K8S_DIR"/[0-9]*/; do printf '  %s\n' "$(basename "$d")"; done
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
  local c out rc bad=0 n=0
  if ! docker info >/dev/null 2>&1; then
    warn "Docker isn't running, so nothing was cleaned. Start Docker and run this again."
    return 1
  fi
  for c in "$DOCKER_DIR"/[0-9]*/cleanup.sh; do
    [ -f "$c" ] || continue
    out=$(bash "$c" 2>&1); rc=$?
    n=$((n + 1))
    # show what was removed or what went wrong; skip the "already clean" lines
    printf '%s\n' "$out" | grep -E 'removed|could not|⚠' || true
    [ "$rc" -eq 0 ] || bad=$((bad + 1))
  done
  if [ "$bad" -eq 0 ]; then ok "All $n Docker scenarios are clean"
  else warn "$bad of $n Docker scenarios could not be fully cleaned (see the lines above). Check: docker ps -a"; return 1
  fi
}

# ------------------------------------------------------------------- k8s --
k8s_clean() {
  local c
  if ! command -v kubectl >/dev/null 2>&1 || ! kubectl cluster-info >/dev/null 2>&1; then
    warn "No Kubernetes cluster reachable, so there is nothing to clean. Check: kubectl config current-context"
    return 0
  fi
  echo "Cleaning Kubernetes scenarios (current kubectl context: $(kubectl config current-context 2>/dev/null || echo none))"
  for c in "$K8S_DIR"/[0-9]*/*/cleanup.py "$K8S_DIR"/[0-9]*/exercises/*/cleanup.py; do
    [ -f "$c" ] && python3 "$c" 2>&1
  done
}

# ----------------------------------------------------------- interactive --
menu() {
  clear 2>/dev/null || true
  bold "🔥 Troubleshooting Arena: break it, find it, fix it"
  echo
  local i=1 entries=()
  for d in "$GITTS_DIR"/[0-9]*/;  do entries+=("git:${d%/}");    printf '  %2d) 🌿 %s\n' $i "$(title_of "$d")"; i=$((i+1)); done
  echo
  echo "  🐳 Docker scenarios: open docker/scenarios/README.md (run by hand)"
  echo "  ☸️  Kubernetes scenarios: open kubernetes/scenarios/README.md (run by hand)"
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
  k8s)
    case "${2:-}" in
      clean) k8s_clean ;;
      *) echo "Kubernetes scenarios are run by hand. Open kubernetes/scenarios/README.md"
         echo "Reset everything with: ./labs.sh k8s clean" ;;
    esac ;;
  git)
    case "${2:-}" in
      clean) git_clean ;;
      ""|help) list ;;
      *) d=$(scenario_dir git "$2"); if [ "${3:-}" = fix ]; then git_fix "$d"; else git_break "$d"; fi ;;
    esac ;;
  *) sed -n '2,12p' "$0" ;;
esac
