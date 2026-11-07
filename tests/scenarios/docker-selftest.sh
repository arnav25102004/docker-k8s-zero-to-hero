#!/usr/bin/env bash
# Self-test for docker/scenarios/_lib.sh and the harness helpers.
# Usage: bash tests/scenarios/docker-selftest.sh
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO/docker/scenarios/_lib.sh"
cd "$REPO" || exit 1
# shellcheck source=lib.sh
source "$REPO/tests/scenarios/lib.sh" 2>/dev/null || true

PASS=0; FAIL=0; SKIP=0
FAILED_NAMES=""

check() { # check MSG CMD... (passes when CMD succeeds)
  local msg="$1"
  shift
  if "$@"; then printf '    ok: %s\n' "$msg"; else printf '    FAIL: %s\n' "$msg"; return 1; fi
}
rc_is() { [ "$1" -eq "$2" ]; }
has() { printf '%s' "$1" | grep -q -- "$2"; }

run_test() {
  local name="$1" out rc
  printf '== %s\n' "$name"
  out=$("$name" 2>&1); rc=$?
  printf '%s\n' "$out"
  if [ "$rc" -eq 77 ]; then
    SKIP=$((SKIP + 1)); printf 'SKIP %s (needs scenario 02)\n' "$name"
  elif [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1)); printf '✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES="$FAILED_NAMES $name"; printf '❌ %s\n' "$name"
  fi
}

test_port_busy() {
  docker rm -f zz-portholder >/dev/null 2>&1
  docker run -d --name zz-portholder -p 8199:80 busybox:1.36 busybox httpd -f -p 80 >/dev/null || return 1
  local out rc
  out=$(bash -c "source '$LIB'; port_free 8199" 2>&1); rc=$?
  docker rm -f zz-portholder >/dev/null 2>&1
  local f=0
  check "returns 1" rc_is "$rc" 1 || f=1
  check "names the holder" has "$out" 'zz-portholder' || f=1
  check "gives the fix" has "$out" 'docker rm -f zz-portholder' || f=1
  return $f
}

test_first_pull_message() {
  docker rmi busybox:1.36 >/dev/null 2>&1
  local out f=0
  out=$(bash -c "source '$LIB'; ensure_image busybox:1.36 '2 MB'" 2>&1)
  check "says downloading" has "$out" 'Downloading busybox:1.36' || f=1
  check "image exists" docker image inspect busybox:1.36 >/dev/null || f=1
  return $f
}

test_wait_for() {
  local f=0 out rc
  out=$(bash -c "source '$LIB'; wait_for 'true thing' 3 true" 2>&1); rc=$?
  check "true returns 0" rc_is "$rc" 0 || f=1
  out=$(bash -c "source '$LIB'; wait_for 'false thing' 2 false" 2>&1); rc=$?
  check "false returns 1" rc_is "$rc" 1 || f=1
  check "says still not ready" has "$out" 'still not ready after 2s' || f=1
  return $f
}

test_no_daemon_message() {
  local out rc f=0
  out=$(DOCKER_HOST=unix:///nonexistent.sock bash -c "source '$LIB'; need_docker" 2>&1); rc=$?
  check "exit 1" rc_is "$rc" 1 || f=1
  check "friendly message" has "$out" "Docker isn't running" || f=1
  return $f
}

test_any_cwd() {
  [ -d "$REPO/docker/scenarios/02-port-clash" ] || return 77
  local f=0
  (cd /tmp && bash "$REPO/docker/scenarios/02-port-clash/break/break.sh") >/dev/null 2>&1
  check "d02-draw running" [ "$(container_state d02-draw)" = running ] || f=1
  bash "$REPO/docker/scenarios/02-port-clash/cleanup.sh" >/dev/null 2>&1
  return $f
}

test_cleanup_idempotent() {
  local f=0 out rc i
  for i in 1 2; do
    out=$(bash -c "source '$LIB'; scenario_cleanup d99" 2>&1); rc=$?
    check "run $i exits 0" rc_is "$rc" 0 || f=1
    check "run $i prints cleaned up" has "$out" '✅ Scenario d99 cleaned up' || f=1
  done
  return $f
}

test_run_cycle_catches_early_assert() {
  local tmp out rc f=0
  tmp=$(mktemp -d) || return 1
  mkdir -p "$tmp/break" "$tmp/fix"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/cleanup.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/fix/fix.sh"
  printf '#!/usr/bin/env bash\necho boom-output\nexit 3\n' > "$tmp/break/break.sh"
  # 1) first of two asserts fails (break.sh fine this time)
  printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/break/break.sh"
  out=$(bash -c "source '$REPO/tests/scenarios/lib.sh'; broken(){ assert_eq a b first; assert_eq a a second; }; fixed(){ true; }; run_cycle '$tmp' d98" 2>&1); rc=$?
  check "run_cycle fails" rc_is "$rc" 1 || f=1
  check "reports broken step" has "$out" 'FAILED at step: broken' || f=1
  # 2) failing break.sh shows its output
  printf '#!/usr/bin/env bash\necho boom-output\nexit 3\n' > "$tmp/break/break.sh"
  out=$(bash -c "source '$REPO/tests/scenarios/lib.sh'; broken(){ true; }; fixed(){ true; }; run_cycle '$tmp' d98" 2>&1); rc=$?
  check "failing script exits 1" rc_is "$rc" 1 || f=1
  check "shows script output" has "$out" 'boom-output' || f=1
  rm -rf "$tmp"
  return $f
}

for t in test_run_cycle_catches_early_assert test_port_busy test_first_pull_message test_wait_for test_no_daemon_message \
         test_any_cwd test_cleanup_idempotent; do
  run_test "$t"
done

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || { printf 'Failed:%s\n' "$FAILED_NAMES"; exit 1; }
