# Lab K09: Resources, QoS & Quotas

> ⏱ 50 min · 🟡 Intermediate

## 🎯 What you'll learn
- **Requests** (used for scheduling) vs **limits** (enforced at runtime)
- Why Pods go **Pending** ("Insufficient cpu"), and how to read the evidence
- OOMKilled vs CPU throttling
- QoS classes and who gets evicted first
- Namespace guardrails: **LimitRange** and **ResourceQuota**

## 🧠 Concept in 60 seconds
```yaml
resources:
  requests: { cpu: 100m, memory: 128Mi }   # "reserve this for me". The scheduler uses it.
  limits:   { cpu: 500m, memory: 256Mi }   # "never let me exceed this". The kernel enforces it.
```
- `cpu: 100m` = 100 millicores = 0.1 of a core. `memory: 128Mi` = 128 mebibytes.
- The scheduler places a Pod only on a node with enough **unrequested allocatable** capacity. Actual usage doesn't matter.
- Exceed the **CPU** limit → throttled (slow). Exceed the **memory** limit → **OOMKilled**.

## 🧪 Hands-on

### Step 1: How much room does the node have?
```bash
kubectl describe node | grep -A 8 'Allocated resources'
kubectl get node -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory
```

### Step 2: Ask for too much → Pending (class-slide scenario)
```bash
kubectl create deployment big --image=nginx:1.27-alpine --replicas=3 --dry-run=client -o yaml \
  | kubectl set resources --local -f - --requests=cpu=1500m -o yaml \
  | kubectl apply -f -
kubectl get pods -l app=big
```
Depending on your node size, some Pods are **Pending**. Investigate exactly as the slide suggests:
```bash
kubectl describe pod -l app=big | grep -A 5 Events
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i -E 'FailedScheduling|insufficient' | tail -3
```
Expected: `0/1 nodes are available: 1 Insufficient cpu.` The scheduler is telling you exactly why.
```bash
kubectl delete deployment big
```

### Step 3: OOMKilled
```bash
kubectl run oom --image=python:3.12-alpine --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"oom","image":"python:3.12-alpine","command":["python","-c","x=bytearray(300*1024*1024)"],"resources":{"limits":{"memory":"64Mi"}}}]}}'
sleep 10
kubectl get pod oom                                        # OOMKilled
kubectl get pod oom -o jsonpath='{.status.containerStatuses[0].state.terminated}'; echo
kubectl delete pod oom
```

### Step 4: QoS classes
```bash
kubectl apply -f kubernetes/09-resources-qos/qos-pods.yaml
kubectl get pods -l lab=qos -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```
| QoS | Rule | Eviction order under node memory pressure |
|---|---|---|
| `Guaranteed` | requests == limits (cpu & memory) for every container | last |
| `Burstable` | some requests/limits set | middle |
| `BestEffort` | nothing set | **first** |

### Step 5: Live usage (needs metrics-server)
```bash
kubectl top nodes
kubectl top pods
```
If you see `Metrics API not available`, install metrics-server as shown in [Lab K13 Step 1](../13-autoscaling/README.md).

### Step 6: Namespace guardrails
```bash
kubectl apply -f kubernetes/09-resources-qos/namespace-guardrails.yaml
kubectl -n team-quota run nolimits --image=nginx:1.27-alpine
kubectl -n team-quota get pod nolimits -o jsonpath='{.spec.containers[0].resources}'; echo   # LimitRange injected defaults
kubectl -n team-quota describe quota budget

kubectl -n team-quota create deployment many --image=nginx:1.27-alpine --replicas=8
kubectl -n team-quota get pods                          # only up to the quota
kubectl -n team-quota get rs -l app=many -o name | xargs kubectl -n team-quota describe | grep -i 'exceeded quota' | head -2
```
🔍 When a quota blocks creation, the Pods don't go Pending: they're **never created**. The error appears on the **ReplicaSet**, not on Pods. That surprises a lot of people.

## 🏭 In production
- **Always set requests.** Without them, the scheduler packs nodes blindly and your Pods are BestEffort, the first to be evicted.
- **Memory:** set limit = request (or close to it). Predictable, no surprise OOMs under node pressure.
- **CPU limits** are debated: they can cause throttling even when the node is idle. Many teams set CPU requests but no CPU limits for latency-sensitive services. Know your team's policy.
- Base numbers on measurements (`kubectl top`, Prometheus, VPA recommendations), not guesses.

## ✅ Checkpoint
<details><summary>1. A node runs at 10% real CPU, yet new Pods are Pending with "Insufficient cpu". How?</summary>

Scheduling uses **requests**, not usage. The existing Pods have *reserved* (requested) the node's CPU even though they don't use it.
</details>
<details><summary>2. Which QoS class is evicted first under memory pressure?</summary>

BestEffort, then Burstable Pods using more than their request, and Guaranteed last.
</details>

## 🔥 Now break it
Requests, limits and quotas cause some of the most confusing failures:
- [K08](../scenarios/08-ai-trainer-oomkilled/README.md): an OOM kill with no error
- [K19](../scenarios/19-hackathon-quota/README.md): a deploy that creates nothing (quota)
- [K20](../scenarios/20-surprise-limitrange-oom/README.md): a limit nobody wrote (LimitRange)
- [K40](../scenarios/40-stall-that-asked-for-too-much/README.md): a limit above the namespace maximum
- [K42](../scenarios/42-who-gets-evicted-first/README.md): who gets evicted first (QoS)

## 🧹 Cleanup
```bash
kubectl delete -f kubernetes/09-resources-qos/ --ignore-not-found
```

➡️ Next: [K10: Storage & StatefulSets](../10-storage-statefulsets/README.md)
