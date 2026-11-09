#!/usr/bin/env bash
# D01 fix: put the fixed Dockerfile in work/, then rebuild, remove and run again.
# Every Docker command is printed first; they are the same ones you type by hand.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

jupyter_up() {
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 'http://localhost:8101/api/status?token=change-me-123')" = "200" ]
}

need_docker
prepare_work "$HERE"
rm -f "$HERE/../work/fix.sh"
cd "$HERE/.." || die "Could not enter the scenario folder"

run_shown docker build -t d01-jupyter:1.0 work \
  || die "The build failed. Read the message above, then try again."
run_shown_quiet docker rm -f d01-jupyter
run_shown_quiet docker run -d --name d01-jupyter -p 8101:8888 d01-jupyter:1.0 \
  || die "docker run failed. Is port 8101 free?"

wait_for "Jupyter to answer on port 8101" 90 jupyter_up \
  || die "Jupyter didn't come up in time. Check: docker logs d01-jupyter"

show_next "✅ Fixed. Now verify it yourself:" \
  "docker ps" \
  "Then open http://localhost:8101/lab?token=change-me-123"
