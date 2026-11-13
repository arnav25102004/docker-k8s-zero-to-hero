# Section 5: Scaling, self-healing and releases

Probes and self-healing, autoscaling, rolling updates and deployment strategies.

**Syllabus topics:** health probes and self-healing, autoscaling, rolling updates and deployment strategies.

## The five scenarios (4 minutes each)

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S5.1** | [Running, healthy, and never any visitors](1-kanboard-never-ready/README.md) | readiness probe | *It's running. It's healthy. It just never gets any visitors.* |
| **S5.2** | [The impatient guard](2-showdown-slow-start/README.md) | liveness probe and slow start | *A perfectly healthy app keeps getting killed, again and again, every few seconds.* |
| **S5.3** | [The autoscaler that shrugs](3-showdown-hpa-not-scaling/README.md) ⏳ | HorizontalPodAutoscaler | *Traffic is pouring in. The autoscaler shrugs: "unknown".* |
| **S5.4** | [The Friday release](4-showdown-bad-rollout/README.md) | rolling update held back, rollback | *Friday, 6 PM. The release goes out. Nobody notices… because Kubernetes saved you.* |
| **S5.5** | [No error, no goodbye (Kubernetes edition)](5-ai-trainer-oomkilled/README.md) ⏳ | resource limits, OOM kill | *Your AI model was training. Then it vanished. No error. No goodbye. And Kubernetes keeps bringing it back to die again.* |

## Exercises (self-paced, with hints)

| # | Exercise | What it teaches |
|---|---|---|
| **S5.x1** | [The doorbell on the wrong door](exercises/1-doorbell-on-the-wrong-door/README.md) | readiness: wrong door |
| **S5.x2** | [The biryani that needs 20 seconds](exercises/2-biryani-that-needs-20-seconds/README.md) | liveness: too early |
| **S5.x3** | [Two probes, two mistakes](exercises/3-two-probes-two-mistakes/README.md) | two probes, two faults |
| **S5.x4** | [The robot that cannot move the stalls](exercises/4-robot-that-cannot-move-the-stalls/README.md) | PodDisruptionBudget |
| **S5.x5** | [The autoscaler pointing at nobody](exercises/5-autoscaler-pointing-at-nobody/README.md) | autoscaler: wrong target |

⏳ = start its `break.sh` one scenario early: it takes longer than a minute to set up or to fix.

← [All sections](../README.md)
