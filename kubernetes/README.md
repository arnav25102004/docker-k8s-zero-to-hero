# ☸️ Track 2: Kubernetes

By the end of this track you can deploy, expose, update, scale, secure, and debug real applications on Kubernetes, and explain *why* each production practice exists.

**Before you start:** a running cluster ([00-setup](../00-setup/README.md)) and the course images loaded ([K01 Step 8](01-cluster-tour/README.md#step-8-prepare-the-course-image-for-the-cluster-)).

| # | Lab | Time | Level |
|---|---|---|---|
| **K00** ⭐ | [**Kubernetes Foundations**: why orchestration, how Kubernetes thinks](00-foundations/README.md) · [quiz](00-foundations/quiz.md) | 2.5–3h | 🟢 |
| K01 | [Tour of a Cluster](01-cluster-tour/README.md) | 40m | 🟢 |
| K02 | [Pods](02-pods/README.md) | 50m | 🟢 |
| K03 | [Namespaces, Labels & Selectors](03-namespaces-labels/README.md) | 30m | 🟢 |
| K04 | [Deployments: Self-Healing You Can See](04-deployments/README.md) | 45m | 🟢 |
| K05 | [Services & DNS](05-services/README.md) | 50m | 🟢→🟡 |
| K06 | [Rolling Updates: "One More Thing…"](06-rollouts/README.md) | 50m | 🟡 |
| K07 | [ConfigMaps & Secrets](07-config-secrets/README.md) | 45m | 🟡 |
| K08 | [Health Probes](08-probes/README.md) | 50m | 🟡 |
| K09 | [Resources, QoS & Quotas](09-resources-qos/README.md) | 50m | 🟡 |
| K10 | [Storage & StatefulSets](10-storage-statefulsets/README.md) | 50m | 🟡 |
| K11 | [Jobs & CronJobs](11-jobs-cronjobs/README.md) | 30m | 🟢→🟡 |
| K12 | [Gateway API & Canary Releases](12-gateway-ingress/README.md) | 60m | 🟡→🔴 |
| K13 | [Autoscaling](13-autoscaling/README.md) | 40m | 🟡 |
| K14 | [RBAC & ServiceAccounts](14-rbac/README.md) | 40m | 🟡 |
| K15 | [Network Policies](15-network-policies/README.md) | 40m | 🟡→🔴 |
| K16 | [Pod Security](16-pod-security/README.md) | 40m | 🟡→🔴 |
| K17 | [Scheduling & Availability](17-scheduling/README.md) | 60m | 🔴 |
| K18 | [🏆 Capstone: The Showdown Goes to Production](18-capstone/README.md) | 2h | 🔴 |
| 🔥 | [Break-and-fix scenarios K01 … K45](scenarios/README.md) (separate from the labs above) | ~8h | 🟢→🔴 |

[`stack/`](stack/README.md) holds the shared frontend + Redis manifests used by K04–K13.

**The story arc:** K04: votes jump between Pods → K05: shared Redis fixes it → K06: ship v2 🦄 mid-vote with 0 failures → K07: swap the whole poll via config → K12: canary 10% of traffic → K13: the Pod wall grows by itself → K18: survive the Gauntlet.
