# Pinned images for the Docker scenarios

Every image has linux/amd64 and linux/arm64 builds and is pinned to an exact tag.
Heavy images are limited to Jupyter (D01, D06, D07) and VS Code (D04); everything else is about 160 MB or less.

`preload.sh` reads the table below (first column = image, second column = tag, both in backticks) and pulls each one.
If you change a pin here, change it in the scenario scripts too, and the other way round.

| Image | Tag | Used by | Size |
|-------|-----|---------|------|
| `quay.io/jupyter/base-notebook` | `2026-11-02` | D01, D06, D07 (all reuse this tag) | ~343 MB |
| `excalidraw/excalidraw` | `latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | D02, D09 | ~44 MB |
| `corentinth/it-tools` | `2024.10.22-7ca5933` | D02, D05, D08, D09 | ~24 MB |
| `redis` | `7.4.12-alpine` | D03 | ~17 MB |
| `python` | `3.12-alpine` | D03 (API base image), D09, D11, D12, D14, D15 | ~19 MB |
| `codercom/code-server` | `4.145.2` | D04 | ~380 MB |
| `busybox` | `1.36` | D07 (helper that creates and `chown`s files in the volume), D12 (helper that reads `scores.json` out of the volume) | ~2 MB |
| `nginx` | `1.27.5-alpine` | D10 and D13 (`FROM` line of their Dockerfiles) | ~23 MB |
| `postgres` | `16.15-alpine` | D15 (the database in `compose.yaml`) | ~116 MB |

Total if you pull everything: about 970 MB.
