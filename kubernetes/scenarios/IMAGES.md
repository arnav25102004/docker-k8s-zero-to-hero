# Images used by the Kubernetes break/fix scenarios

All are pinned to an exact tag (or digest) and published for linux/amd64 and linux/arm64.

| Image | Size | Used by |
|---|---|---|
| `excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | about 44 MB | K01, K02, K05 |
| `hashicorp/http-echo:1.0.0` | about 17 MB | K31 to K34 (a tiny web server that answers every request with a fixed text: the chai stall, the samosa stall, the canteen counter) |
| `busybox:1.36` | about 4 MB | K01 to K07, K09 to K14, K16, K18 to K24, K26, K27, K29 to K36 (the `visitor` Pod; K35 and K36: also the tiny web server itself, busybox `httpd`; K14: the player Pods; K13: also the enforcement probe in `k-13-probe`; K26: also the wait-for-Redis helper; K29: also the log helper), K25 (no visitor: the `load` Pod that generates the traffic), K15 (the `envcheck` Pod in its README) |
| `curlimages/curl:8.11.1` | about 12 MB | K14 (the leaderboard bot), and the test harness only for the rest (`in_cluster_http`, and the test specs of K12, K13, K16, K19, K23, K26, K27, K30) |
| `python:3.12-alpine` | about 19 MB download (about 80 MB on disk) | K03, K07, K11, K12, K13 (Cats vs Dogs, the app code comes from a ConfigMap); K08 (the AI trainer script); K15 (the score worker); K17 (the AI trainer); K20, K24, K25, K26, K30 (Cats vs Dogs); K23 (the Campus Today page); K28 (the reset Job) |
| `corentinth/it-tools:2024.10.22-7ca5933` | about 24 MB | K04 |
| `kanboard/kanboard:v1.2.57` | about 33 MB | K06, K10 |
| `adminer:5.4.1` | about 46 MB | K09 |
| `redis:7.4.12-alpine` | about 59 MB on disk | K12, K13, K15, K26, K28 and K30 (the real Redis behind Service `redis`) |
| `nginx:1.27.5-alpine` | about 21 MB download (about 50 MB on disk) | K16 (serves the Dosa Dash page from a ConfigMap), K21 (the broken notice board) |
| `traefik/whoami:v1.10.4` | about 6 MB | K18 (the app that tells you which Pod answered) |
| `b4bz/homer:v25.10.1` | about 7 MB | K19, K27 (the Homer dashboard) |
| `nginxinc/nginx-unprivileged:1.27.5-alpine` | about 22 MB | K21 (the fix), K22, K29 (the notice board pages) |
| `registry.k8s.io/metrics-server/metrics-server:v0.9.1` | about 22 MB | K25 (a cluster add-on, installed only if your cluster has none yet) |
