# Images used by the Kubernetes break/fix scenarios

All are pinned to an exact tag (or digest) and published for linux/amd64 and linux/arm64.

| Image | Size | Used by |
|---|---|---|
| `excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | about 44 MB | K01 |
| `busybox:1.36` | about 4 MB | K01 (the `visitor` Pod) |
| `curlimages/curl:8.11.1` | about 12 MB | test harness only (`in_cluster_http`), not shown to learners |
