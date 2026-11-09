#!/usr/bin/env bash
# D06 fix: the same trainer with the fixed compose.yaml. Every command is printed first.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

has_exited() { [ "$(docker inspect -f '{{.State.Status}}' d06-trainer-1 2>/dev/null)" = "exited" ]; }

need_docker
ensure_image "python:3.12-alpine" "about 19 MB"

prepare_work "$HERE"
cd "$HERE/.." || die "Could not enter the scenario folder"

run_shown docker compose -f work/compose.yaml up -d --build \
  || die "docker compose up failed. Is Docker healthy?"

wait_for "the training to finish" 60 has_exited \
  || die "The container never stopped, which is unexpected. Run cleanup.sh and try again."

show_next "✅ Fixed. Now verify it yourself:" \
  "docker compose -f work/compose.yaml logs trainer" \
  "docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer-1"
