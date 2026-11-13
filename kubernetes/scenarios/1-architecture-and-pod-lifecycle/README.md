# Section 1: Architecture and Pod lifecycle

How a Pod comes to life, and which component notices when it does not: scheduler, API server, kubelet, container runtime.

**Syllabus topics:** Kubernetes architecture, control-plane and worker-node components, container runtimes, Pods and lifecycle management.

## The five scenarios (4 minutes each)

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S1.1** | [The whiteboard that never starts](1-excalidraw-pending/README.md) | scheduler, requests | *We asked for a whiteboard. Kubernetes heard "a data centre".* |
| **S1.2** | [The one-letter typo](2-image-typo/README.md) | kubelet + container runtime (image pull) | *One missing letter. Kubernetes tries, waits, tries again… forever.* |
| **S1.3** | [The loop](3-showdown-crashloop/README.md) | Pod lifecycle, restart policy | *It starts. It dies. It starts. It dies. Welcome to the loop.* |
| **S1.4** | [Stuck before it starts](4-showdown-init-stuck/README.md) | init containers, Pod phases | *Cats vs Dogs is waiting for its database. Forever.* |
| **S1.5** | [The Pod that will not leave](5-pod-that-will-not-leave/README.md) | API server, finalizers, termination | *You said delete. Kubernetes said yes. The Pod did not get the message.* |

## Exercises (self-paced, with hints)

| # | Exercise | What it teaches |
|---|---|---|
| **S1.x1** | [The trainer wants a GPU](x1-ai-trainer-needs-gpu/README.md) | GPU request: Pending, node selection |
| **S1.x2** | [One replica too many](x2-whoami-anti-affinity/README.md) | anti-affinity: one replica too many |
| **S1.x3** | [Half ready](x3-log-sidecar-half-ready/README.md) | multi-container Pod: half ready |

⏳ = start its `break.sh` one scenario early: it takes longer than a minute to set up or to fix.

← [All sections](../README.md)
