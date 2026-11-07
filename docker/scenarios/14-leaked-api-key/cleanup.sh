#!/usr/bin/env bash
# Removes everything scenario D14 created (including every d14-weather:* tag). Safe to run any time, any number of times.
set -u
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"
docker info >/dev/null 2>&1 || { warn "Docker isn't running: nothing to clean up."; exit 0; }
scenario_cleanup d14
# Belt and braces: remove any d14-weather tag, even one built without the label.
for img in $(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep '^d14-weather:'); do
  docker rmi -f "$img" >/dev/null 2>&1
done
exit 0
