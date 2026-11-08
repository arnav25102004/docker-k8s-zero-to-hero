# Lab K04: Deployments: Self-Healing You Can *See*

> ⏱ 45 min · 🟢 Beginner

## 🎯 What you'll learn
- Create a Deployment, imperatively and from YAML
- Watch **self-healing** live: delete Pods and see Kubernetes replace them
- **Scale** from 3 to 10 Pods with one command
- How Deployment → ReplicaSet → Pods fit together
- Why per-Pod memory is a trap (the votes jump around!)

## 🧠 Concept in 60 seconds
```
Deployment "api"   (replicas: 3, Pod template)
   └── ReplicaSet "api-7c9f8d6b5"     keeps EXACTLY 3 Pods matching the template
          ├── Pod api-7c9f8d6b5-abcde
          ├── Pod api-7c9f8d6b5-fghij
          └── Pod api-7c9f8d6b5-klmno
```
You declare **"I want 3"**. A controller loops forever: *count → too few? create; too many? delete.* You never start or restart Pods yourself.

## 🧪 Hands-on

### Step 1: The class-slide way (imperative)
```bash
kubectl create deployment web --image=nginx:1.27-alpine
kubectl get deployments
kubectl get pods
kubectl describe deployment web
kubectl delete deployment web
```

### Step 2: 🎬 The Showdown on Kubernetes
> Prerequisite: images loaded into your cluster ([K01 Step 8](../01-cluster-tour/README.md#step-8-prepare-the-course-image-for-the-cluster-)).

```bash
kubectl apply -f kubernetes/04-deployments/deployment.yaml     # the api: 3 replicas
kubectl apply -f kubernetes/stack/frontend.yaml                # the nginx frontend
kubectl rollout status deployment/api
kubectl get deploy,rs,pods -o wide
```
Open the app (leave this running in its own terminal):
```bash
kubectl port-forward svc/frontend 8080:80
```
→ **http://localhost:8080**. Look at the **Pod wall**: three coloured tiles, one per Pod, each named like `api-6d4b…-x7k2p`. Those are real Kubernetes Pods answering your browser.

### Step 3: 💀 Murder some Pods (Kubernetes doesn't mind)
Put the browser and a terminal side by side. Terminal 2:
```bash
kubectl get pods -l app=api -w
```
Terminal 3, delete **all** the API Pods:
```bash
kubectl delete pod -l app=api --wait=false
```
Watch:
- the terminal: `Terminating` … and brand-new Pods `ContainerCreating` → `Running` within seconds
- the browser: old tiles fade to grey 🪦, new tiles pop in 🆕, and the failed counter shows how short the outage was

You didn't restart anything. The **ReplicaSet controller** saw actual (0) ≠ desired (3) and fixed it.
```bash
kubectl describe rs -l app=api | grep -A 8 Events
```

### Step 4: 🚀 Scale to 10
```bash
kubectl scale deployment api --replicas=10
```
The Pod wall fills up with ten tiles. Scale back:
```bash
kubectl scale deployment api --replicas=3
```
⚠️ In production, change `replicas:` in Git and re-apply, or let an autoscaler do it (Lab K13). Imperative `scale` drifts from your YAML.

### Step 5: 🤔 Something's wrong with the votes…
Vote ten times for cats and watch the counters. The totals **jump around** 😵. Each Pod stores votes in **its own memory**, and each request may land on a different Pod. Three Pods, three different "truths".

And when you deleted the Pods in Step 3? Every vote was **gone**.

> **Stateless Pods + shared state** is the cloud-native pattern. Lab K05 adds Redis and fixes it.

### Step 6: Take a Pod out of the Deployment
```bash
POD=$(kubectl get pod -l app=api -o name | head -1)
kubectl label $POD app=quarantine --overwrite
kubectl get pods -L app
```
🔍 The ReplicaSet now counts only 2 Pods with `app=api`, so it **creates a replacement**. The relabelled Pod keeps running but receives no traffic: a real-world way to isolate a misbehaving Pod for investigation.
```bash
kubectl delete pod -l app=quarantine
```

## 🏭 In production
- Run **≥ 2–3 replicas** of anything user-facing, so a Pod or node failure is a non-event.
- Add **PodDisruptionBudgets** (K17) so maintenance never takes all replicas at once.
- Kubernetes *tries* to maintain desired state. If there's no room, new Pods stay **Pending** ([scenario K01](../scenarios/01-excalidraw-pending/README.md)).

## ✅ Checkpoint
<details><summary>1. You delete a Pod owned by a Deployment. Who replaces it?</summary>

The ReplicaSet controller (in kube-controller-manager) creates a new Pod; the scheduler picks a node; the kubelet on that node starts it.
</details>
<details><summary>2. Why did the vote counts jump around?</summary>

Each replica kept its own in-memory tally, and the Service spread requests across replicas.
</details>

## 🧹 Cleanup
Keep everything running for Lab K05, or:
```bash
kubectl delete -f kubernetes/04-deployments/deployment.yaml -f kubernetes/stack/frontend.yaml
```

➡️ Next: [K05: Services & DNS](../05-services/README.md)
