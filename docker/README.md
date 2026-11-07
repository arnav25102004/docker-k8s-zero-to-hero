# 🐳 Track 1: Docker

By the end of this track you can package any app into an image, run multi-container systems with Compose, and debug containers like an on-call engineer.

| # | Lab | Time | Level |
|---|---|---|---|
| **D00** ⭐ | [**Docker Foundations**: why containers exist, how Docker works](00-foundations/README.md) · [quiz](00-foundations/quiz.md) | 2.5–3h | 🟢 |
| D01 | [First Steps & the Image Arcade](01-first-steps/README.md) | 30m | 🟢 |
| D02 | [Images & the Container Lifecycle](02-images-containers-lifecycle/README.md) | 40m | 🟢 |
| D03 | [Meet the Showdown: ports, logs, exec, inspect](03-inside-containers/README.md) | 45m | 🟢 |
| D04 | [Your First Dockerfile](04-first-dockerfile/README.md) | 45m | 🟢 |
| D05 | [Production-Grade Dockerfiles](05-production-dockerfiles/README.md) | 60m | 🟡 |
| D06 | [Volumes & Persistent Data](06-volumes/README.md) | 40m | 🟢→🟡 |
| D07 | [Container Networking](07-networking/README.md) | 45m | 🟡 |
| D08 | [Docker Compose](08-compose/README.md) | 50m | 🟡 |
| D09 | [Health Checks & Restart Policies](09-health-restart/README.md) | 35m | 🟡 |
| D10 | [Registries, Tags & Digests](10-registry-tags/README.md) | 35m | 🟡 |
| D11 | [Resource Limits & Security](11-limits-security/README.md) | 45m | 🟡→🔴 |
| 🔥 | [Break-and-fix scenarios D01 … D15](scenarios/README.md) | 3–4h | 🟢→🟡 |

**The story arc:** D03 ends with a cliffhanger (votes vanish when the container is replaced). D06 fixes it with Redis + volumes, D07 adds load balancing, and D08 packages it all with Compose and releases v2 🦄.

➡️ Next track: [☸️ Kubernetes](../kubernetes/README.md)
