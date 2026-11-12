#!/usr/bin/env bash
# Offline self-test for in_cluster_pod / in_cluster_http in k8s-lib.sh. No cluster needed:
# a fake kubectl plays the part of the API. Usage: bash tests/scenarios/k8s-lib-selftest.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# fake kubectl: behaviour comes from $FAKE_MODE (ok | refused | stuck | flaky)
cat >"$WORK/kubectl" <<'FAKE'
#!/bin/bash
echo "$*" >>"$FAKE_DIR/log"
case "$1" in
  run) n=$(cat "$FAKE_DIR/runs" 2>/dev/null || echo 0); echo $((n + 1)) >"$FAKE_DIR/runs" ;;
  get) n=$(cat "$FAKE_DIR/runs")
    case "$FAKE_MODE" in
      ok | warmup) printf Succeeded ;;
      refused) printf Failed ;;
      stuck) printf Pending ;;
      flaky) [ "$n" -ge 2 ] && printf Succeeded || printf Pending ;;
    esac ;;
  logs) n=$(cat "$FAKE_DIR/runs")
    case "$FAKE_MODE" in
      refused) printf 000 ;;
      warmup) [ "$n" -ge 3 ] && printf 200 || printf 000 ;;
      *) printf '%s' "${FAKE_OUT:-}" ;;
    esac ;;
esac
exit 0
FAKE
chmod +x "$WORK/kubectl"
export PATH="$WORK:$PATH" FAKE_DIR="$WORK"
export Z2H_POD_WAIT=2 Z2H_POD_TRIES=2
# shellcheck source=k8s-lib.sh
source "$REPO/tests/scenarios/k8s-lib.sh"

FAILS=0
chk() { if [ "$2" = "$3" ]; then printf '  ok: %s\n' "$1"; else printf '  FAIL: %s (expected %q, got %q)\n' "$1" "$3" "$2"; FAILS=$((FAILS + 1)); fi; }
reset() { rm -f "$WORK/runs"; : >"$WORK/log"; }

reset; export FAKE_MODE=ok FAKE_OUT=200
chk "a finished Pod's answer is returned" "$(in_cluster_http ns http://x 2>/dev/null)" 200
reset; export FAKE_MODE=refused
chk "curl refused gives 000 (a real refusal)" "$(in_cluster_http ns http://x 2>/dev/null)" 000
reset; export FAKE_MODE=stuck
chk "a helper Pod that never runs gives ERR, not 000" "$(in_cluster_http ns http://x 2>/dev/null)" ERR
reset
chk "the reason is printed on stderr" "$(in_cluster_http ns http://x 2>&1 >/dev/null | grep -c 'helper Pod never finished')" 1
reset; export FAKE_MODE=flaky FAKE_OUT=200
chk "it retries and recovers on the second try" "$(in_cluster_http ns http://x 2>/dev/null)" 200
reset; export FAKE_MODE=ok FAKE_OUT=200
in_cluster_pod ns '{"spec":{"containers":[{"name":"@NAME@"}]}}' >/dev/null
chk "@NAME@ is replaced in the overrides" "$(grep -c '"name":"ic-' "$WORK/log")" 1
reset
in_cluster_pod ns '' sh -c 'echo hi' >/dev/null
chk "the command follows --command --" "$(grep -c -- '--command -- sh -c echo hi' "$WORK/log")" 1

reset; export FAKE_MODE=warmup
chk "in_cluster_http_wait waits until the app answers" "$(in_cluster_http_wait ns http://x 200 6 2>/dev/null)" 200
reset; export FAKE_MODE=refused
chk "in_cluster_http_wait gives up and reports the last answer" "$(in_cluster_http_wait ns http://x 200 2 2>/dev/null)" 000

# a failing scenario must still get its cleanup.sh run, so it leaves nothing behind
# shellcheck source=lib.sh
source "$REPO/tests/scenarios/lib.sh" 2>/dev/null || true
SC="$WORK/scenario"; mkdir -p "$SC/break" "$SC/fix"
printf '#!/bin/bash\necho x >> "%s/cleanups"\n' "$WORK" >"$SC/cleanup.sh"
printf '#!/bin/bash\nexit 1\n' >"$SC/break/break.sh"
: >"$WORK/cleanups"
run_cycle_k8s "$SC" k99 >/dev/null 2>&1; rc=$?
chk "a failing scenario makes run_cycle_k8s fail" "$rc" 1
chk "its cleanup ran again after the failure (initial + after)" "$(wc -l <"$WORK/cleanups" | tr -d ' ')" 2

printf '\n%s\n' "$([ "$FAILS" -eq 0 ] && echo 'all passed' || echo "$FAILS failed")"
[ "$FAILS" -eq 0 ]
