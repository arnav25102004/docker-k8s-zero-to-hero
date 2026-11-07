#!/usr/bin/env bash
# D06 fix: same training, but with a 1 GB memory limit (it needs about 600 MB).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/../../_lib.sh"

IMAGE="quay.io/jupyter/base-notebook:2026-11-02"

# The "training" script: 5 epochs, each loads 120 MB (5 x 120 = 600 MB in total).
TRAIN='import time
data = []
for epoch in range(1, 6):
    print(f"epoch {epoch}/5 ... loading 120 MB", flush=True)
    data.append(bytearray(b"x") * (120 * 1024 * 1024))
    time.sleep(1)
print("✅ model trained", flush=True)'

has_exited() { [ "$(docker inspect -f '{{.State.Status}}' d06-trainer 2>/dev/null)" = "exited" ]; }

need_docker
ensure_image "$IMAGE" "about 343 MB"

say "Re-running the training with a 1 GB memory limit…"
docker rm -f d06-trainer >/dev/null 2>&1
# --entrypoint python: Python is the container's main process, so Docker's own
# OOM bookkeeping is unambiguous and `docker logs` shows only the training output.
docker run -d --name d06-trainer --label z2h.scenario=d06 \
  --memory 1g --memory-swap 1g --entrypoint python \
  "$IMAGE" -c "$TRAIN" >/dev/null \
  || die "docker run failed. Is Docker healthy?"

wait_for "the training to finish" 60 has_exited \
  || die "The container never stopped, which is unexpected. Run cleanup.sh and try again."

show_next "✅ Fixed. Now verify it yourself:" \
  "docker logs d06-trainer" \
  "docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer"
