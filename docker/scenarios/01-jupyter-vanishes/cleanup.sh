#!/usr/bin/env bash
# Removes everything scenario D01 created. Safe to run any time, any number of times.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
docker info >/dev/null 2>&1 || { warn "Docker isn't running: nothing to clean up."; exit 0; }
scenario_cleanup d01
