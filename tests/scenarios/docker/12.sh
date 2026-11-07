#!/usr/bin/env bash
# Spec for scenario D12 (12-high-score-lost-on-stop). Sourced by tests/scenarios/docker.sh.

# post_demo: put three demo scores on the board, the same way break.sh does.
post_demo() {
  local n
  for n in Asha:42 Ravi:35 Meera:28; do
    curl -s -o /dev/null -X POST -H 'Content-Type: application/json' \
      -d "{\"name\":\"${n%%:*}\",\"score\":${n##*:}}" http://localhost:8112/api/scores
  done
}

# timed_stop: docker stop -t 10, sets STOP_SECS to the whole seconds it took.
timed_stop() {
  local t0 t1
  t0=$(date +%s)
  docker stop -t 10 d12-game >/dev/null 2>&1
  t1=$(date +%s)
  STOP_SECS=$((t1 - t0))
}

saved_file() { docker run --rm -v d12-data:/data busybox:1.36 cat /data/scores.json 2>&1; }

broken() {
  assert_eq "$(container_state d12-game)" "running" "container d12-game is running"
  assert_eq "$(curl -s --max-time 5 http://localhost:8112/api/scores)" "[]" "the board is empty after the restart (demo scores lost)"
  post_demo
  timed_stop
  assert_eq "$([ "$STOP_SECS" -ge 9 ] && echo slow || echo "fast($STOP_SECS)")" "slow" "docker stop took >= 9 s (took ${STOP_SECS}s)"
  assert_eq "$(docker inspect -f '{{.State.ExitCode}}' d12-game)" "137" "ExitCode is 137 (killed)"
  local saved
  saved="$(saved_file)"
  case "$saved" in
    *Asha*) assert_eq "found" "missing" "scores.json must NOT contain the demo scores" ;;
    *) assert_eq "missing" "missing" "scores.json lacks the demo scores" ;;
  esac
  docker start d12-game >/dev/null 2>&1
  assert_eq "$(docker exec d12-game ps | awk '$1==1 {print $4}')" "/bin/sh" "PID 1 is /bin/sh"
}

fixed() {
  assert_eq "$(container_state d12-game)" "running" "container d12-game is running"
  assert_eq "$(docker exec d12-game ps | awk '$1==1 {print $4}')" "python" "PID 1 is python"
  post_demo
  timed_stop
  assert_eq "$([ "$STOP_SECS" -le 3 ] && echo fast || echo "slow($STOP_SECS)")" "fast" "docker stop took <= 3 s (took ${STOP_SECS}s)"
  assert_eq "$(docker inspect -f '{{.State.ExitCode}}' d12-game)" "0" "ExitCode is 0 (clean exit)"
  local saved
  saved="$(saved_file)"
  assert_contains "$saved" "Asha" "scores.json contains Asha"
  assert_contains "$saved" "Ravi" "scores.json contains Ravi"
  assert_contains "$saved" "Meera" "scores.json contains Meera"
  docker start d12-game >/dev/null 2>&1
  wait_for_api
  assert_contains "$(curl -s --max-time 5 http://localhost:8112/api/scores)" "Asha" "after docker start, Asha is back on the board"
}

wait_for_api() {
  local i=0
  while [ "$i" -lt 15 ]; do
    curl -s -o /dev/null --max-time 1 http://localhost:8112/api/scores && return 0
    sleep 1
    i=$((i + 1))
  done
  return 1
}
