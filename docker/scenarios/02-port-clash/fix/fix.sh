#!/usr/bin/env bash
# D02 fix: the shortcut for the fixed second line in the README (host port 8202).
# It prints every Docker command before it runs it, exactly as you would type it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

TOOLS_IMAGE="corentinth/it-tools:2024.10.22-7ca5933"

tools_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8202)" = "200" ]; }

need_docker
say "Remove the stuck IT-Tools container, then run line 2 again with a free host port"
run_shown_quiet docker rm -f d02-tools
run_shown docker run -d --name d02-tools -p 8202:80 "$TOOLS_IMAGE" \
  || die "docker run failed. Is Docker healthy?"

wait_for "IT-Tools to answer on port 8202" 60 tools_up \
  || die "IT-Tools didn't come up in time. Check: docker logs d02-tools"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker ps --format '{{.Names}}  {{.Ports}}'" \
  "Then open http://localhost:8102 and http://localhost:8202"
