#!/usr/bin/env bash
# D05 break: try to start IT-Tools with a mistyped image tag (two characters swapped).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

REAL_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"

need_docker
bash "$HERE/../cleanup.sh"
port_free 8105 || die "Port 8105 is busy, so this scenario can't start. Free it (see above) and run break.sh again."
# Have the real image ready so fix.sh is quick, even on slow Wi-Fi.
ensure_image "$REAL_IMAGE" "about 24 MB"

say "Deploying IT-Tools (the Friday-night version, typed from memory)…"
printf '$ docker run -d --name d05-tools -p 8105:80 corentinth/it-tools:2024.10.22-7ca5393\n'
docker run -d --name d05-tools --label z2h.scenario=d05 -p 8105:80 corentinth/it-tools:2024.10.22-7ca5393
printf 'docker run finished with exit code %s\n' "$?"

show_next \
  "Docker printed an error and IT-Tools is not running. Open http://localhost:8105 and the page can't be reached." \
  "Start with: docker ps -a"
exit 0
