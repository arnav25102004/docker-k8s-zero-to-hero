# Images used by the Kubernetes break/fix scenarios

All are pinned to an exact tag (or digest) and published for linux/amd64 and linux/arm64.

| Image | Size | Used by |
|---|---|---|
| `excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9` | about 44 MB | S1.1, S1.2, S3.2 |
| `hashicorp/http-echo:1.0.0` | about 17 MB | S1.5, S2.1, S2.2, S2.3, S3.4, S4.x2, S4.x3, S5.x1, S5.x4, S5.x5, S6.1, S6.3, S6.4, S6.x1, S6.x2 (a tiny web server that answers every request with a fixed text: the chai stall, the samosa stall, the canteen counter) |
| `busybox:1.36` | about 4 MB | S1.1, S1.2, S1.3, S1.4, S1.x2, S1.x3, S2.1, S2.2, S2.5, S3.1, S3.2, S3.3, S3.4, S3.5, S4.1, S4.2, S4.3, S4.4, S4.5, S4.x1, S4.x2, S4.x3, S4.x4, S5.1, S5.2, S5.3, S5.4, S5.x1, S5.x2, S5.x3, S5.x4, S5.x5, S6.1, S6.2, S6.3, S6.4, S6.5, S6.x1, S6.x3 (the `visitor` Pod; S5.x2 and S5.x3: also the tiny web server itself, busybox `httpd`; S4.4: the player Pods; S3.5: also the enforcement probe in `k-13-probe`; S1.4: also the wait-for-Redis helper; S1.x3: also the log helper), S5.3 (no visitor: the `load` Pod that generates the traffic), S2.2 (the `envcheck` Pod in its README) |
| `curlimages/curl:8.11.1` | about 12 MB | S4.4 (the leaderboard bot), and the test harness only for the rest (`in_cluster_http`, and the test specs of S1.4, S2.2, S3.3, S3.5, S4.1, S6.2, S6.x3) |
| `python:3.12-alpine` | about 19 MB download (about 80 MB on disk) | S1.3, S3.3, S3.5, S5.2, S5.4 (Cats vs Dogs, the app code comes from a ConfigMap); S5.5 (the AI trainer script); S1.x1 (the AI trainer); S1.4, S5.3, S6.5, S6.x3 (Cats vs Dogs); S4.1 (the Campus Today page); S2.4 (the reset Job) |
| `corentinth/it-tools:2024.10.22-7ca5933` | about 24 MB | S3.1 |
| `kanboard/kanboard:v1.2.57` | about 33 MB | S4.3, S5.1 |
| `adminer:5.4.1` | about 46 MB | S4.2 |
| `redis:7.4.12-alpine` | about 59 MB on disk | S1.4, S2.4, S3.3, S3.5 and S6.x3 (the real Redis behind Service `redis`) |
| `nginx:1.27.5-alpine` | about 21 MB download (about 50 MB on disk) | S4.5 (the broken notice board), S4.x4 (the kitchen that wants root) |
| `traefik/whoami:v1.10.4` | about 6 MB | S1.x2 (the app that tells you which Pod answered) |
| `b4bz/homer:v25.10.1` | about 7 MB | S6.2 (the Homer dashboard) |
| `nginxinc/nginx-unprivileged:1.27.5-alpine` | about 22 MB | S4.5 (the fix), S1.x3, S4.x1 (the notice board pages), S4.x4 (the fix) |
| `registry.k8s.io/metrics-server/metrics-server:v0.9.1` | about 22 MB | S5.3 (a cluster add-on, installed only if your cluster has none yet) |

The optional monitoring stack from lab S6.2 (Prometheus, Grafana and friends) is pulled by Helm when you run `./scripts/install-monitoring.sh`; it is not listed here and `preload.sh` does not fetch it. Budget about 2 GB of memory and a few hundred MB of download.

S6.3 uses `helm` (installed on your machine, not an image) and pulls only `http-echo`. S3.4 uses the Envoy Gateway controller, installed once with `./scripts/install-gateway.sh`: it pulls its own images (about 1 GB of memory in use), so `preload.sh` does not fetch them.
