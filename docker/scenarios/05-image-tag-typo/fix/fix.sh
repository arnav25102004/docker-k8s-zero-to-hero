#!/usr/bin/env bash
# D05 fix: copy fix/ into work/, then build and run, the same commands the README shows.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

tools_up() { [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:8105)" = "200" ]; }

need_docker
prepare_work "$HERE"
rm -f "$HERE/../work/break.sh" "$HERE/../work/fix.sh"
cd "$HERE/../work" || die "Could not enter work/"
run_shown docker build -t d05-tools:1.0 . || die "The build failed. Read the error above."
run_shown docker rm -f d05-tools
run_shown docker run -d --name d05-tools -p 8105:80 d05-tools:1.0 \
  || die "docker run failed. Is port 8105 free?"
wait_for "IT-Tools to answer on port 8105" 60 tools_up \
  || die "IT-Tools didn't come up in time. Check: docker logs d05-tools"

show_next "✅ Fixed. Now verify it yourself:" \
  "Open http://localhost:8105 (playground: the port 8105 URL), and http://localhost:8105/hello.html" \
  "docker ps"
