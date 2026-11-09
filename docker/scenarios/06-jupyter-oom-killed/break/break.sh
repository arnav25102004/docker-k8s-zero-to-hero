#!/usr/bin/env bash
# D06 break: build the trainer and start it with compose. Every command is printed first.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

has_exited() { [ "$(docker inspect -f '{{.State.Status}}' d06-trainer-1 2>/dev/null)" = "exited" ]; }

need_docker
bash "$HERE/../cleanup.sh"
ensure_image "python:3.12-alpine" "about 19 MB"

prepare_work "$HERE"
cd "$HERE/.." || die "Could not enter the scenario folder"

run_shown docker compose -f work/compose.yaml up -d --build \
  || die "docker compose up failed. Is Docker healthy?"

wait_for "the container to stop" 60 has_exited \
  || die "The container never stopped, which is unexpected. Run cleanup.sh and try again."

show_next \
  "Your AI model was training. Now the container is gone from 'docker ps': no error, no goodbye." \
  "docker compose -f work/compose.yaml ps -a"
