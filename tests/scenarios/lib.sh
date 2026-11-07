#!/usr/bin/env bash
# Test helpers for the scenario harness. Sourced by docker.sh and the self-test.

# Every failed assert bumps this counter; run_cycle resets and checks it around
# broken()/fixed(), so an early failed assert can't be hidden by a later passing one.
ASSERT_FAILS=0

assert_eq() { # ACTUAL EXPECTED MSG
  if [ "$1" = "$2" ]; then
    printf '    ok: %s\n' "$3"
  else
    printf '    FAIL: %s (expected "%s", got "%s")\n' "$3" "$2" "$1"
    ASSERT_FAILS=$((ASSERT_FAILS + 1))
    return 1
  fi
}

assert_contains() { # HAYSTACK NEEDLE MSG
  case "$1" in
    *"$2"*) printf '    ok: %s\n' "$3" ;;
    *) printf '    FAIL: %s (missing "%s")\n' "$3" "$2"; ASSERT_FAILS=$((ASSERT_FAILS + 1)); return 1 ;;
  esac
}

assert_cmd_fails() { # MSG CMD...
  local msg="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '    FAIL: %s (command succeeded but should fail)\n' "$msg"
    ASSERT_FAILS=$((ASSERT_FAILS + 1))
    return 1
  fi
  printf '    ok: %s\n' "$msg"
}

http_code() { # URL
  curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1"
}

container_state() { # NAME
  docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null
}

# nothing_left ID: fail if anything labelled z2h.scenario=ID remains.
nothing_left() {
  local label="z2h.scenario=$1" left
  left="$(docker ps -aq --filter "label=$label" 2>/dev/null)$(docker network ls -q --filter "label=$label" 2>/dev/null)$(docker volume ls -q --filter "label=$label" 2>/dev/null)$(docker images -q --filter "label=$label" 2>/dev/null)"
  [ -z "$left" ]
}

# _step LABEL N SCRIPT: run a script, capture output, show its tail on failure.
_step() {
  local label="$1" n="$2" script="$3" out
  out=$(bash "$script" 2>&1) && return 0
  printf '  FAILED at step: %s (cycle %s)\n' "$label" "$n"
  printf '%s\n' "$out" | tail -n 20 | sed 's/^/    | /'
  return 1
}

# _check LABEL N FUNC: run broken/fixed; fails if it returns non-zero OR any assert failed.
_check() {
  local label="$1" n="$2" fn="$3"
  ASSERT_FAILS=0
  if ! "$fn" || [ "$ASSERT_FAILS" -gt 0 ]; then
    printf '  FAILED at step: %s (cycle %s)\n' "$label" "$n"
    return 1
  fi
}

# run_cycle DIR ID: cleanup -> break -> broken -> fix -> fixed -> cleanup -> nothing left.
# Twice. broken() and fixed() must be defined by the caller. Fails fast.
run_cycle() {
  local dir="$1" id="$2" n
  for n in 1 2; do
    printf '  -- cycle %s/2\n' "$n"
    _step cleanup "$n" "$dir/cleanup.sh" || return 1
    _step break.sh "$n" "$dir/break/break.sh" || return 1
    _check broken "$n" broken || return 1
    _step fix.sh "$n" "$dir/fix/fix.sh" || return 1
    _check fixed "$n" fixed || return 1
    _step "final cleanup" "$n" "$dir/cleanup.sh" || return 1
    nothing_left "$id" || { printf '  FAILED at step: nothing-left check (cycle %s)\n' "$n"; return 1; }
  done
}
