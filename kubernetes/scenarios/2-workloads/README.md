# Section 2: Workloads

Deployments and ReplicaSets, StatefulSets, DaemonSets, Jobs and CronJobs: the right controller for the right job.

**Syllabus topics:** Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs and CronJobs.

## The five scenarios (4 minutes each)

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S2.1** | [The label on the wrong object](1-label-on-the-wrong-object/README.md) | Deployment, ReplicaSet, labels on the template | *The label is right there. Kubernetes is looking somewhere else.* |
| **S2.2** | [The stall that opens one at a time](2-stall-that-opens-one-at-a-time/README.md) ⏳ | StatefulSet: ordered start, stable names | *Three stalls were ordered. One opened. The other two are not even built.* |
| **S2.3** | [The watchman who skipped a gate](3-watchman-skipped-a-gate/README.md) | DaemonSet: one per node, taints | *A watchman was posted at every gate. One gate has nobody. Kubernetes says everything is fine.* |
| **S2.4** | [The nightly reset that gave up](4-leaderboard-reset-job/README.md) | Job: retries, backoffLimit | *The midnight reset ran. Three times. Then gave up.* |
| **S2.5** | [The nightly reset that never started](5-nightly-reset-that-never-started/README.md) ⏳ | CronJob: schedule, suspend | *It is scheduled for every minute. It has been "every minute" for three weeks. Nothing has run.* |

⏳ = start its `break.sh` one scenario early: it takes longer than a minute to set up or to fix.

← [All sections](../README.md)
