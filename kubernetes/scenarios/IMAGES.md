# Images used by the Kubernetes break/fix scenarios

All are pinned to an exact tag (or digest) and published for linux/amd64 and linux/arm64.

| Image | Size | Used by |
|---|---|---|
| `excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | about 44 MB | K01, K02, K05 |
| `busybox:1.36` | about 4 MB | K01, K02, K05 (the `visitor` Pod) |
| `curlimages/curl:8.11.1` | about 12 MB | test harness only (`in_cluster_http`), not shown to learners |
| `python:3.12-alpine` | about 19 MB download (about 80 MB on disk) | K03 and later Cats vs Dogs scenarios (the app code comes from a ConfigMap); K08 (the AI trainer script) |
| `corentinth/it-tools:2024.10.22-7ca5933` | about 24 MB | K04 and later IT-Tools scenarios |
| `kanboard/kanboard:v1.2.57` | about 33 MB | K06 and later Kanboard scenarios |
| `adminer:5.4.1` | about 46 MB | K09 |
