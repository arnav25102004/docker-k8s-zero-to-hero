# Pinned images for the Docker scenarios

Every image has linux/amd64 and linux/arm64 builds and is pinned to an exact tag.

| Image | Tag | Used by | Size |
|-------|-----|---------|------|
| `quay.io/jupyter/base-notebook` | `2026-11-02` | D01, D06, D07 (all reuse this tag) | ~343 MB |
| `excalidraw/excalidraw` | `latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | D02, D09 | ~44 MB |
| `corentinth/it-tools` | `2024.10.22-7ca5933` | D02, D05, D08, D09 | ~24 MB |
| `redis` | `7.4.12-alpine` | D03 | ~17 MB |
| `python` | `3.12-alpine` | D03 (base of `apps/api/Dockerfile`, which pins this tag), D09 (runs `board.py`), D11 (base of `*/Dockerfile`, serves the portfolio with `http.server`), D12 (base of `*/Dockerfile`, runs the Dosa Dash `server.py`) | ~19 MB |
| `codercom/code-server` | `4.145.2` | D04 | ~380 MB |
| `busybox` | `1.36` | D07 (helper that creates and `chown`s files in the volume), D12 (helper that reads `scores.json` out of the volume) | ~2 MB |
| `nginx` | `1.27.5-alpine` | D10 (serves the QR app; `FROM` line in `10-qr-app-build-fails/*/Dockerfile`) | ~23 MB |
