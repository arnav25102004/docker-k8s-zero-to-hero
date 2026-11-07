#!/usr/bin/env bash
# Test helpers for the scenario harness. Sourced by docker.sh and the self-test.

assert_eq() { # ACTUAL EXPECTED MSG
  if [ "$1" = "$2" ]; then
    printf '    ok: %s\n' "$3"
  else
    printf '    FAIL: %s (expected "%s", got "%s")\n' "$3" "$2" "$1"
    return 1
  fi
}

assert_contains() { # HAYSTACK NEEDLE MSG
  case "$1" in
    *"$2"*) printf '    ok: %s\n' "$3" ;;
    *) printf '    FAIL: %s (missing "%s")\n' "$3" "$2"; return 1 ;;
  esac
}

assert_cmd_fails() { # MSG CMD...
  local msg="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '    FAIL: %s (command succeeded but should fail)\n' "$msg"
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

# run_cycle DIR ID: cleanup -> break -> broken -> fix -> fixed -> cleanup -> nothing left.
# Twice. broken() and fixed() must be defined by the caller. Fails fast.
run_cycle() {
  local dir="$1" id="$2" n
  for n in 1 2; do
    printf '  -- cycle %s/2\n' "$n"
    bash "$dir/cleanup.sh" >/dev/null 2>&1 || { printf '  FAILED at step: cleanup (cycle %s)\n' "$n"; return 1; }
    bash "$dir/break/break.sh" >/dev/null 2>&1 || { printf '  FAILED at step: break.sh (cycle %s)\n' "$n"; return 1; }
    broken || { printf '  FAILED at step: broken (cycle %s)\n' "$n"; return 1; }
    bash "$dir/fix/fix.sh" >/dev/null 2>&1 || { printf '  FAILED at step: fix.sh (cycle %s)\n' "$n"; return 1; }
    fixed || { printf '  FAILED at step: fixed (cycle %s)\n' "$n"; return 1; }
    bash "$dir/cleanup.sh" >/dev/null 2>&1 || { printf '  FAILED at step: final cleanup (cycle %s)\n' "$n"; return 1; }
    nothing_left "$id" || { printf '  FAILED at step: nothing-left check (cycle %s)\n' "$n"; return 1; }
  done
}
