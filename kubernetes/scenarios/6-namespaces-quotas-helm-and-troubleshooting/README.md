# Section 6: Namespaces, quotas, Helm and troubleshooting

Namespaces and resource quotas, Helm releases, labels and annotations, and the habit of finding what really ran.

**Syllabus topics:** namespaces and resource quotas, Helm charts, labels and annotations, Kubernetes troubleshooting.

## The five scenarios (4 minutes each)

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S6.1** | [Applied here, looking there](1-applied-here-looking-there/README.md) | namespaces and kubectl context | *The deploy said "created". The cluster says "No resources found". Both are telling the truth.* |
| **S6.2** | [The deploy that created nothing](2-hackathon-quota/README.md) | ResourceQuota | *The deploy succeeded. Kubernetes created… nothing.* |
| **S6.3** | [The upgrade that broke the stall](3-upgrade-that-broke-the-stall/README.md) ⏳ | Helm: release, history, rollback | *Helm said "deployed". Helm was not lying. Helm was not helping either.* |
| **S6.4** | [Two stalls, one signboard](4-two-stalls-one-signboard/README.md) | labels, selectors, annotations | *Some customers get hot chai. Some get… yesterday's.* |
| **S6.5** | [The limit nobody wrote](5-surprise-limitrange-oom/README.md) | LimitRange: what ran vs what you wrote | *"Nobody set a memory limit. The app still got killed for exceeding it."* |

## Exercises (self-paced, with hints)

| # | Exercise | What it teaches |
|---|---|---|
| **S6.x1** | [The stall that asked for too much](x1-stall-that-asked-for-too-much/README.md) | LimitRange maximum |
| **S6.x2** | [Who gets evicted first](x2-who-gets-evicted-first/README.md) | QoS classes and eviction order |
| **S6.x3** | [The Friday 5 PM outage (the finale)](x3-friday-5pm-outage/README.md) | three faults at once |

⏳ = start its `break.sh` one scenario early: it takes longer than a minute to set up or to fix.

← [All sections](../README.md)
