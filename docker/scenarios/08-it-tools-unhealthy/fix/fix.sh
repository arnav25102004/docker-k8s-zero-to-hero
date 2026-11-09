#!/usr/bin/env bash
# D08 fix: copy fix/ into work/, then build and run, the same commands the README shows.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

is_healthy() { [ "$(docker inspect -f '{{.State.Health.Status}}' d08-tools 2>/dev/null)" = "healthy" ]; }

need_docker
cd "$HERE/.." || die "Could not enter the scenario folder"
rm -rf work
run_shown cp -R fix work || die "Could not copy fix/ to work/"
run_shown docker build -t d08-tools:1.0 work || die "The build failed. Read the error above."
run_shown docker rm -f d08-tools
run_shown docker run -d --name d08-tools -p 8108:80 d08-tools:1.0 \
  || die "docker run failed. Is port 8108 free?"

wait_for "Docker to report the container healthy" 60 is_healthy \
  || die "IT-Tools didn't become healthy in time. Check: docker inspect -f '{{json .State.Health}}' d08-tools"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker ps --filter name=d08-tools"
