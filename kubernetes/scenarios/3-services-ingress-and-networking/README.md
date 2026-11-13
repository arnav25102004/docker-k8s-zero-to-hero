# Section 3: Services, ingress and networking

How traffic finds Pods: Services, DNS, ingress routing and Network Policies.

**Syllabus topics:** Services and ingress routing, Kubernetes networking and network policies.

## The five scenarios (4 minutes each)

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S3.1** | [Running is not reachable](1-it-tools-no-endpoints/README.md) | Service selector and endpoints | *Every Pod is Running. Every request fails.* |
| **S3.2** | [Right Pod, wrong door](2-excalidraw-wrong-port/README.md) | port and targetPort | *Endpoints exist. The Pod is fine. Still: connection refused.* |
| **S3.3** | [Same cluster, same name, "never heard of it"](3-showdown-dns-namespaces/README.md) | DNS across namespaces | *The Redis is running. The app is running. And the app swears Redis does not exist.* |
| **S3.4** | [The route to the wrong stall](4-route-to-the-wrong-stall/README.md) ⏳ | Gateway API / Ingress routing | *One front door, two paths. One path leads to a stall that does not exist.* |
| **S3.5** | [Security hardened the network. Now nothing can find anything.](5-lockdown-blocks-dns/README.md) | NetworkPolicy and DNS | *Security locked the app down so it can only talk to Redis. And now the app cannot even find Redis.* |

⏳ = start its `break.sh` one scenario early: it takes longer than a minute to set up or to fix.

← [All sections](../README.md)
