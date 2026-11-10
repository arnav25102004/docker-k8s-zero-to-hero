# Lab K06: Rolling Updates: "One More Thing…" 🦄

> ⏱ 50 min · 🟡 Intermediate

## 🎯 What you'll learn
- Ship a new version **while people are using the app**, with **zero failed requests**
- `maxSurge` / `maxUnavailable` and what they mean for capacity
- Watch a **broken release get stuck** while users notice nothing
- Roll back in one command, and record *why* each revision exists
- The `preStop` trick that real platforms use for truly zero-downtime deploys

## 🧠 Concept in 60 seconds
Change anything in the Pod template (image, env, ...) and the Deployment creates a **new ReplicaSet**, then shifts Pods over gradually:
```
 old RS (v1): ████  →  ████  →  ███   →  ██    →  █     →  (0)
 new RS (v2): (0)   →  █     →  ██    →  ███   →  ████  →  ████
```
With `maxUnavailable: 0`, an old Pod is only removed once a new one is **Ready**. A broken version can never replace working ones.

## 🧪 Hands-on

### Step 1: Deploy v1 (Cats vs Dogs)
```bash
kubectl apply -f kubernetes/stack/                       # frontend + redis
kubectl apply -f kubernetes/06-rollouts/deployment.yaml  # api v1, 4 replicas
kubectl rollout status deployment/api
kubectl port-forward --address 0.0.0.0 svc/frontend 8080:80   # phones on the Wi-Fi can reach it
```
⚠️ `--address 0.0.0.0` opens the app to everyone on the same network. Use it only on a network you trust, and press Ctrl+C when the demo is over. (On a playground such as Killercoda or iximiuz, `--address 0.0.0.0` is how the platform's port link reaches it.) On your own laptop without an audience, drop `--address 0.0.0.0`.

Open http://localhost:8080 on the big screen, and have the audience open http://<laptop-ip>:8080 on their phones. **Get the votes flowing.** Point at the **"failed" counter: 0**. Remember that number.

### Step 2: 🎤 "One more thing…"
Second terminal, watching Pods:
```bash
kubectl get pods -l app=api -w
```
Third terminal: the release. **v2 adds a third contender:**
```bash
kubectl set env deployment/api APP_VERSION=2.0.0 VOTE_OPTIONS="cats:🐱:Cats,dogs:🐶:Dogs,unicorns:🦄:Unicorns"
kubectl annotate deployment/api kubernetes.io/change-cause="v2.0.0 one more thing: unicorns" --overwrite
kubectl rollout status deployment/api
```
On screen:
- ✨ a banner announces **version 2.0.0**, and **🦄 Unicorns** appear
- for a few seconds the Pod wall shows **old and new Pods side by side**: a rolling update you can see
- existing votes are **still there** (Redis)
- the **failed counter is still 0**

Then say it out loud: *"We just replaced every server while 50 people were using it, and nobody noticed."* 🎤⬇️

```bash
kubectl get rs -l app=api                   # old RS scaled to 0, kept for rollback
kubectl rollout history deployment/api
```

### Step 3: 💥 A broken release
Someone ships an image tag that doesn't exist:
```bash
kubectl set image deployment/api api=z2h/api:9.9.9
kubectl annotate deployment/api kubernetes.io/change-cause="v9.9.9 oops" --overwrite
kubectl rollout status deployment/api --timeout=30s     # times out: stuck
kubectl get pods -l app=api                              # 1 new Pod ImagePullBackOff, 4 old still Running
```
Look at the browser: **still working, still 0 failures.** The broken Pod never became Ready, so `maxUnavailable: 0` kept every old Pod serving. Only the *rollout* is stuck; users are fine.

### Step 4: ⏪ Roll back
```bash
kubectl rollout undo deployment/api
kubectl rollout status deployment/api
kubectl rollout history deployment/api
# or to a specific revision:  kubectl rollout undo deployment/api --to-revision=1
```
Now roll back once more to return to v1, and watch the unicorns disappear live. 🦄👋

> ℹ️ kubectl may warn that the `last-applied-configuration` annotation is out of date: the live object no longer matches your YAML file. In real teams, fix the file (or `git revert`) so the next `kubectl apply` doesn't undo your rollback.
>
> 🧭 Roll back only after understanding the impact, and follow your team's procedure. Rollback isn't always safe, for example after a database migration.

### Step 5: Why the `preStop` sleep?
Open [`deployment.yaml`](deployment.yaml) and find `lifecycle.preStop`. When a Pod is deleted, two things happen **in parallel**:
1. the kubelet sends SIGTERM to the container
2. every node updates its routing to stop sending traffic to that Pod

If (1) wins the race, a few requests hit a Pod that's already gone, so the failed counter ticks up. `sleep 5` in `preStop` keeps the Pod serving until (2) has finished everywhere. Remove it, repeat Step 2 under load, and compare the failed counter.

### Step 6: Restart, pause, and batch
```bash
kubectl rollout restart deployment/api          # new Pods, same spec (e.g. after a ConfigMap change)
kubectl rollout pause deployment/api
kubectl set env deployment/api APP_VERSION=3.0.0
kubectl set resources deployment/api --requests=cpu=50m,memory=32Mi
kubectl rollout resume deployment/api           # ONE rollout containing both changes
```

## 🏭 In production
- Rollouts are only as safe as your **readiness probes** (K08).
- Canary releases, blue/green, and automatic rollback on error spikes: **Argo Rollouts**, **Flagger**, or Gateway API weights (K12).
- CI/CD pipelines run `kubectl rollout status --timeout=…` and fail the deploy if it doesn't finish.

## ✅ Checkpoint
<details><summary>1. replicas=4, maxSurge=1, maxUnavailable=0. Max Pods during a rollout? Min ready?</summary>

At most 5 Pods; never fewer than 4 ready.
</details>
<details><summary>2. Why did the broken image cause no outage?</summary>

The new Pod never became Ready, and `maxUnavailable: 0` forbids removing old Pods until new ones are Ready.
</details>

## 🧹 Cleanup
Keep the stack for K07, or: `kubectl delete -f kubernetes/06-rollouts/deployment.yaml -f kubernetes/stack/`

➡️ Next: [K07: ConfigMaps & Secrets](../07-config-secrets/README.md)
