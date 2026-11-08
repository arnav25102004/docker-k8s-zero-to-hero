# Images used by the Kubernetes break/fix scenarios

All are pinned to an exact tag (or digest) and published for linux/amd64 and linux/arm64.

| Image | Size | Used by |
|---|---|---|
| `excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | about 44 MB | K01, K02, K05 |
| `busybox:1.36` | about 4 MB | K01 to K07 and K09 to K13 (the `visitor` Pod), K13 (also the enforcement probe in `k-13-probe`), K14 (the player Pods), K15 (the `envcheck` Pod in its README) |
| `curlimages/curl:8.11.1` | about 12 MB | K14 (the leaderboard bot), and the test harness (`in_cluster_http`) |
| `python:3.12-alpine` | about 19 MB download (about 80 MB on disk) | K03, K07, K11, K12, K13 (Cats vs Dogs, the app code comes from a ConfigMap); K08 (the AI trainer script); K15 (the score worker) |
| `corentinth/it-tools:2024.10.22-7ca5933` | about 24 MB | K04 |
| `kanboard/kanboard:v1.2.57` | about 33 MB | K06, K10 |
| `adminer:5.4.1` | about 46 MB | K09 |
| `redis:7.4.12-alpine` | about 59 MB on disk | K12, K13 and K15 (the real Redis behind Service `redis`) |
| `nginx:1.27.5-alpine` | about 21 MB download (about 50 MB on disk) | K16 (serves the Dosa Dash page from a ConfigMap) |
