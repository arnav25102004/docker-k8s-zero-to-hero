# canteen (Helm chart)

Canteen Rush, an ordering app, packaged for Kubernetes: a Deployment and Service, a ConfigMap for the menu, a Secret for the admin token, Redis, an optional autoscaler, a nightly CronJob, an opening-bell hook Job and a `helm test`.

## Install
```bash
helm install canteen ./chart/canteen -n canteen-helm --create-namespace --wait
helm test canteen -n canteen-helm
```

## The settings you will actually change
| Value | Default | What it does |
|---|---|---|
| `replicaCount` | `2` | how many web Pods (ignored when `autoscaling.enabled`) |
| `image.repository` / `image.tag` | `canteen-rush` / chart `appVersion` | which image to run |
| `menu` | three dishes | the menu file (`id\|emoji\|name\|price` per line) |
| `adminToken` / `existingSecret` | demo token / empty | the admin secret; for real use, create a Secret yourself and name it in `existingSecret` |
| `redis.enabled` | `true` | keep orders in Redis so every Pod agrees |
| `autoscaling.enabled` | `false` | add a HorizontalPodAutoscaler (`minReplicas`, `maxReplicas`, `targetCPUUtilizationPercentage`) |
| `cronjob.enabled` / `cronjob.schedule` | `true` / `*/2 * * * *` | the nightly close-day job |
| `openingBell.enabled` | `true` | a one-time Job after the first install |

Per-environment examples: `values-dev.yaml`, `values-prod.yaml`.

## Check it before you install
```bash
helm lint ./chart/canteen
helm template canteen ./chart/canteen | less
```
