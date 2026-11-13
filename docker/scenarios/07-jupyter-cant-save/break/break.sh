#!/usr/bin/env bash
# D07 break: copy break/ into work/ and start the stack from work/compose.yaml.
# Every Docker command is printed (▶ $ ...) exactly as you could type it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

jupyter_up() { curl -s -f -o /dev/null --max-time 2 "http://localhost:8107/api/status?token=change-me-123"; }
backup_done() { [ "$(docker compose -p d07 ps -a backup --format '{{.State}} {{.ExitCode}}' 2>/dev/null)" = "exited 0" ]; }

need_docker
bash "$HERE/../cleanup.sh"
port_free 8107 || die "Port 8107 is busy, so this scenario can't start. Free it (see above) and run break.sh again."

prepare_work "$HERE"
cd "$HERE/.." || die "Could not enter the scenario folder."

say "The first run downloads Jupyter (about 343 MB) and busybox (about 2 MB), unless you already have them."
run_shown docker compose -f work/compose.yaml up -d \
  || die "docker compose up failed. Try it yourself:  docker compose -f work/compose.yaml up"

wait_for "Jupyter to start" 90 jupyter_up \
  || die "Jupyter didn't start in time. Run ./cleanup.sh and try again."
wait_for "the backup job to finish" 30 backup_done \
  || die "The backup job didn't finish. Check: docker compose -f work/compose.yaml logs backup"

scene_set
