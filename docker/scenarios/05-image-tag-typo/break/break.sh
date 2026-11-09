#!/usr/bin/env bash
# D05 break: copy break/ into work/ and run `docker build` there. The build fails; nothing runs.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"
refuse_if_in_work "$HERE"

REAL_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"

need_docker
bash "$HERE/../cleanup.sh"
port_free 8105 || die "Port 8105 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
# Get the course's IT-Tools image ready now, so the rest of the session is quick on slow Wi-Fi.
ensure_image "$REAL_IMAGE" "about 24 MB"

prepare_work "$HERE"
rm -f "$HERE/../work/break.sh" "$HERE/../work/fix.sh"
cd "$HERE/.." || die "Could not enter the scenario folder"
say "Friday night, 11:40 pm. Building the team's image from work/Dockerfile:"
run_shown docker build -t d05-tools:1.0 work
rc=$?
printf 'docker build finished with exit code %s\n' "$rc"

show_next \
  "docker build printed an error and returned to the prompt. There is no image and nothing is running." \
  "Read the error above, line by line. Then follow the README: Investigate."
exit 0
