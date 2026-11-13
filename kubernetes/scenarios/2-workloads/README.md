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

## Exercises (self-paced, with hints)

| # | Exercise | What it teaches |
|---|---|---|
| **S2.x1** | [Delete the owner, keep the Pods](exercises/1-delete-the-owner-keep-the-pods/README.md) | ReplicaSet, ownerReferences, selectors, --cascade=orphan |
| **S2.x2** | [The Pod that comes back with the same name](exercises/2-pod-that-comes-back-with-the-same-name/README.md) | StatefulSet, stable Pod names, headless Service, ordered start and stop |
| **S2.x3** | [A watchman for chosen gates only](exercises/3-watchman-for-chosen-gates-only/README.md) | DaemonSet, nodeSelector, node labels |
| **S2.x4** | [Six tasks, two hands](exercises/4-six-tasks-two-hands/README.md) | Job, completions, parallelism, restartPolicy |
| **S2.x5** | [Run the nightly job right now](exercises/5-run-the-nightly-job-right-now/README.md) | CronJob, create job --from, suspend, concurrencyPolicy |

⏳ = start its `break/run.py` one scenario early: it takes longer than a minute to set up or to fix.

← [All sections](../README.md)
