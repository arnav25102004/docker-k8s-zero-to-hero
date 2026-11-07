#!/usr/bin/env bash
# Usage: ./tests/scenarios/docker.sh [NN ...]   (no args = all present scenarios)
# For each scenario NN: sources tests/scenarios/docker/NN.sh (defines broken()
# and fixed()) and runs two full break/fix cycles.
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO" || exit 1
# shellcheck source=lib.sh
source "$REPO/tests/scenarios/lib.sh"

if [ "$#" -gt 0 ]; then
  NUMS="$*"
else
  NUMS=""
  for d in "$REPO"/docker/scenarios/[0-9][0-9]-*/; do
    [ -d "$d" ] || continue
    b="$(basename "$d")"
    NUMS="$NUMS ${b%%-*}"
  done
fi

PASSED=""; FAILED=""
for nn in $NUMS; do
  printf '== Scenario %s\n' "$nn"
  dir=""
  for d in "$REPO"/docker/scenarios/"$nn"-*/; do [ -d "$d" ] && dir="${d%/}"; done
  spec="$REPO/tests/scenarios/docker/$nn.sh"
  if [ -z "$dir" ]; then printf '  folder docker/scenarios/%s-* not found\n' "$nn"; FAILED="$FAILED $nn"; continue; fi
  if [ ! -f "$spec" ]; then printf '  missing %s\n' "$spec"; FAILED="$FAILED $nn"; continue; fi
  if (
    # shellcheck source=/dev/null
    source "$spec"
    run_cycle "$dir" "d$nn"
  ); then
    PASSED="$PASSED $nn"
  else
    FAILED="$FAILED $nn"
  fi
done

printf '\n== Summary\n'
for nn in $PASSED; do printf '✅ %s\n' "$nn"; done
for nn in $FAILED; do printf '❌ %s\n' "$nn"; done
[ -z "$FAILED" ]
