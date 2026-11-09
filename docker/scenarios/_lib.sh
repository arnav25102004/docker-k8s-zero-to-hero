#!/usr/bin/env bash
# Shared helpers for the Docker break/fix scenarios. Sourced (never executed) by
# break.sh, fix.sh and cleanup.sh. Works on bash 3.2 (macOS) and newer.
#
# Source it with an absolute path built from the script's own location:
#   break/ and fix/ scripts:  source "$(cd "$(dirname "$0")/../.." && pwd)/_lib.sh"
#   cleanup.sh:               source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"

# Git Bash would rewrite paths like /data into C:/Program Files/Git/data.
export MSYS_NO_PATHCONV=1

say()  { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✖ %s\033[0m\n' "$*"; exit 1; }

# Stop early, with one friendly line, when the Docker daemon isn't reachable.
need_docker() {
  if ! docker info >/dev/null 2>&1; then
    die "Docker isn't running. Start Docker Desktop (or the Docker service) and try again."
  fi
}

# port_free PORT: return 0 if nothing listens on PORT. Otherwise explain who
# holds it and how to free it, and return 1.
port_free() {
  local port="$1" holder rc
  holder=$(docker ps --filter "publish=$port" --format '{{.Names}}' 2>/dev/null | head -n 1)
  if [ -n "$holder" ]; then
    warn "Port $port is already used by the container '$holder'."
    printf '   Free it with:  docker rm -f %s\n' "$holder"
    return 1
  fi
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$port"
  rc=$?
  # 7 = connection refused (nothing there). Any other result means something answered.
  if [ "$rc" -ne 7 ]; then
    warn "Port $port is already used by another program on your computer."
    printf '   Pick another port / close that program, then run this again.\n'
    return 1
  fi
  return 0
}

# ensure_image IMAGE SIZE_TEXT: pull IMAGE (with visible progress) if missing.
ensure_image() {
  local image="$1" size="${2:-}"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    say "⬇️  Downloading $image ($size, first time only)…"
    docker pull "$image" || die "Could not download $image. Check your internet connection and try again."
  fi
}

# wait_for DESCRIPTION SECONDS COMMAND...: poll COMMAND once a second.
wait_for() {
  local desc="$1" secs="$2" i=0
  shift 2
  printf '⏳ Waiting for %s ' "$desc"
  while [ "$i" -lt "$secs" ]; do
    if "$@" >/dev/null 2>&1; then
      printf ' '
      ok "ready"
      return 0
    fi
    printf '.'
    sleep 1
    i=$((i + 1))
  done
  if "$@" >/dev/null 2>&1; then
    printf ' '
    ok "ready"
    return 0
  fi
  printf '\n'
  warn "$desc still not ready after ${secs}s"
  return 1
}

# Directory holding this library (docker/scenarios), resolved once at source time.
_Z2H_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# _show_cmd CMD [ARGS...]: print "▶ $ CMD ARGS" the way a learner would type it.
# Words made only of safe characters stay bare; anything else is quoted with
# printf %q, so the printed line can be copy-pasted.
_show_cmd() {
  local line="" a
  for a in "$@"; do
    case "$a" in
      ''|*[!A-Za-z0-9_@%+=:,./-]*) a=$(printf '%q' "$a") ;;
    esac
    line="$line $a"
  done
  say "\$${line}"
}

# run_shown CMD [ARGS...]: print the command in the say style, then run it with
# its output visible. Returns the command's exit status.
run_shown() {
  _show_cmd "$@"
  "$@"
}

# run_shown_quiet CMD [ARGS...]: like run_shown, but hides stdout (stderr stays).
run_shown_quiet() {
  _show_cmd "$@"
  "$@" >/dev/null
}

# prepare_work SRC_DIR: recreate <scenario>/work/ as a fresh copy of SRC_DIR.
# The scenario dir is the PARENT of SRC_DIR (SRC_DIR is <scenario>/break or
# <scenario>/fix), so work/ always sits next to break/ and fix/. Safe when
# work/ is missing; replaces an edited work/.
prepare_work() {
  local src scen
  src="$(cd "$1" 2>/dev/null && pwd)" || die "prepare_work: no such folder: $1"
  scen="$(dirname "$src")"
  [ -n "$scen" ] && [ "$scen" != "/" ] || die "prepare_work: bad folder: $1"
  rm -rf "${scen:?}/work"
  mkdir -p "$scen/work"
  cp -R "$src/." "$scen/work/"
  # Print the command a learner types from the scenario folder (same effect).
  say "\$ rm -rf work && cp -R $(basename "$src") work"
}

# scenario_cleanup ID [SCENARIO_DIR] (ID e.g. d06): remove everything labelled
# z2h.scenario=ID, plus <scenario>/work/. SCENARIO_DIR defaults to
# docker/scenarios/<NN>-* for ID dNN. The compose project is taken down by name
# (-p ID), never by file, so an edited or deleted work/compose.yaml cannot block it.
# Silent, idempotent, never fails.
scenario_cleanup() {
  local id="$1" x scen="${2:-}"
  local label="z2h.scenario=$id"
  if [ -z "$scen" ]; then
    for x in "$_Z2H_LIB_DIR/${id#d}"-*/; do
      [ -d "$x" ] && scen="${x%/}"
    done
  fi
  if [ -n "$scen" ] && [ -d "$scen/work" ]; then
    rm -rf "${scen:?}/work"
  fi
  # compose first: "down -v" also removes the anonymous volumes of its containers.
  docker compose -p "$id" down -v --remove-orphans >/dev/null 2>&1
  # rm -fv: also remove the anonymous volumes (postgres, redis ... declare VOLUME).
  for x in $(docker ps -aq --filter "label=$label" 2>/dev/null); do
    docker rm -fv "$x" >/dev/null 2>&1
  done
  for x in $(docker ps -aq --filter "label=com.docker.compose.project=$id" 2>/dev/null); do
    docker rm -fv "$x" >/dev/null 2>&1
  done
  for x in $(docker network ls -q --filter "label=$label" 2>/dev/null); do
    docker network rm "$x" >/dev/null 2>&1
  done
  for x in $(docker volume ls -q --filter "label=$label" 2>/dev/null); do
    docker volume rm -f "$x" >/dev/null 2>&1
  done
  # Also catch things made by hand (no label): anything named "ID-...". The name
  # filter is a substring match, so keep only names that really start with "ID-".
  for x in $(docker ps -a --filter "name=${id}-" --format '{{.Names}}' 2>/dev/null | grep "^${id}-"); do
    docker rm -fv "$x" >/dev/null 2>&1
  done
  for x in $(docker network ls --filter "name=${id}-" --format '{{.Name}}' 2>/dev/null | grep "^${id}-"); do
    docker network rm "$x" >/dev/null 2>&1
  done
  for x in $(docker volume ls --filter "name=${id}-" --format '{{.Name}}' 2>/dev/null | grep "^${id}-"); do
    docker volume rm -f "$x" >/dev/null 2>&1
  done
  for x in $(docker images -q --filter "label=$label" 2>/dev/null); do
    docker rmi -f "$x" >/dev/null 2>&1
  done
  # Images built by hand from a README (no label): every tag of "ID-...".
  for x in $(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep "^${id}-"); do
    docker rmi -f "$x" >/dev/null 2>&1
  done
  printf '✅ Scenario %s cleaned up\n' "$id"
  return 0
}

# show_next MSG...: the closing block every break.sh / fix.sh prints.
# First arg = what the learner should see; remaining args = what to type next.
show_next() {
  printf '\n\033[1m👀 What you should see now\033[0m\n'
  local first=1 m
  for m in "$@"; do
    if [ "$first" -eq 1 ]; then
      printf '   %s\n' "$m"
      first=0
      printf '\n\033[1m👉 Next\033[0m\n'
    else
      printf '   %s\n' "$m"
    fi
  done
}
