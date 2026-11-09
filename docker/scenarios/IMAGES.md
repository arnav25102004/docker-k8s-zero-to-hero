# Pinned images for the Docker scenarios

Every image has linux/amd64 and linux/arm64 builds. All are pinned to an exact tag except `python:3.12-alpine`, which floats on purpose (it is the shared course base image).
Heavy images are limited to Jupyter (D01, D07) and VS Code (D04); everything else is about 160 MB or less.

`preload.sh` reads the table below (first column = image, second column = tag, both in backticks) and pulls each one.
If you change a pin here, change it in the scenario scripts too, and the other way round.

| Image | Tag | Used by | Size |
|-------|-----|---------|------|
| `quay.io/jupyter/base-notebook` | `2026-11-02` | D01, D07 (both reuse this tag) | ~343 MB |
| `excalidraw/excalidraw` | `latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | D02 (`docker run`), D09 (`compose.yaml`) | ~44 MB |
| `corentinth/it-tools` | `2024.10.22-7ca5933` | D02 (`docker run`), D05, D08 (`FROM` line), D09 (`compose.yaml`) | ~24 MB |
| `redis` | `7.4.12-alpine` | D03 (`docker run`) | ~17 MB |
| `python` | `3.12-alpine` | D03, D06, D09 (`FROM` line of their Dockerfiles), D11, D12, D14, D15 | ~19 MB |
| `codercom/code-server` | `4.145.2` | D04 | ~380 MB |
| `busybox` | `1.36` | D07 (the backup job in `compose.yaml` that creates and `chown`s files in the volume), D12 (helper that reads `scores.json` out of the volume) | ~2 MB |
| `nginx` | `1.27.5-alpine` | D10 and D13 (`FROM` line of their Dockerfiles) | ~23 MB |
| `postgres` | `16.15-alpine` | D15 (the database in `compose.yaml`) | ~116 MB |

Total if you pull everything: about 970 MB.

## Images the scenarios build themselves

These are built on your machine, from a few lines on top of a base image above. They are not pulled and are not in the table, so `preload.sh` ignores them. Each adds only a few KB or MB on top of its base. `cleanup.sh` removes them.

- D01: `d01-jupyter:1.0` (on the Jupyter image)
- D03: `d03-api:1.0` (on `python:3.12-alpine`)
- D05: `d05-tools:1.0` (on IT-Tools)
- D06: `d06-trainer:1.0` (on `python:3.12-alpine`)
- D08: `d08-tools:1.0` (on IT-Tools)
- D09: `d09-board:1.0` (on `python:3.12-alpine`)

D02, D04 and D07 build nothing: they run third-party images as they are.
