# 🔥 Kubernetes break-and-fix scenarios

**30 core scenarios in six sections, plus 14 exercises and a finale.** Each core scenario is a 4-minute live demo that **breaks something in a cluster on purpose**: the class investigates by hand with `kubectl`, then a fix script repairs it. Every scenario has its own folder with a story, a diagram, the concept, the commands to type, a `check.sh` and takeaways.

> **Scenarios vs labs.** Here **K01–K45 means scenario folders** in this directory. They are not the labs K00–K19 in the [Kubernetes track](../README.md).

> ### 🧰 Install these two things first (once)
> **1. metrics-server, right after your cluster is up.** Without it there is no `kubectl top`, the autoscaler (K25) has nothing to read, and the K01 tour is half blind.
> ```bash
> ./scripts/install-metrics-server.sh
> ```
> **2. (Optional) Prometheus and Grafana**, to watch every incident as a graph and an alert. Many scenarios have a short "👀 See it in monitoring" tip that needs it. It needs `helm` and about 2 GB of free memory; the first run takes about five minutes. Lab [K19](../19-observability/README.md) teaches it.
> ```bash
> ./scripts/install-monitoring.sh
> ```
> Every scenario works without it. For a live picture of the cluster as you break it, the [Kubilitics](https://kubilitics.com/) desktop app helps too ([K01, Step 9](../01-cluster-tour/README.md)).

## The plan: 6 sections, 30 scenarios, 120 minutes

Thirty scenarios, grouped into **six sections of five**. Each is a **4-minute live demo**: about 20 seconds of story, 40 seconds to break it, 90 seconds to find the cause with the class, 40 seconds to fix it, 30 seconds for the one-line lesson. Six sections × five scenarios × four minutes = **two hours, non-stop**. Everything else (the overview, the exercises, the finale and the two projects) fits the second two-hour slot.

> 🕐 **Four minutes only works if the next scenario is already broken.** Open a second terminal and run the *next* `break.sh` while you talk through the current lesson (each scenario has its own namespace). Scenarios that take longer to set up or to fix are marked ⏳ in the tables: start those one scenario early.

### The syllabus, section by section
| Section | Syllabus topics covered |
|---|---|
| **1** Architecture and Pod lifecycle | Kubernetes architecture, control-plane and worker-node components, container runtimes, Pods and lifecycle management |
| **2** Workloads | Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs and CronJobs |
| **3** Services, ingress and networking | Services and ingress routing, Kubernetes networking and network policies |
| **4** Configuration, storage and security | ConfigMaps and Secrets, persistent storage, RBAC, security policies |
| **5** Scaling, self-healing and releases | health probes and self-healing, autoscaling, rolling updates and deployment strategies |
| **6** Namespaces, quotas, Helm and troubleshooting | namespaces and resource quotas, Helm charts, labels and annotations, Kubernetes troubleshooting |

Every scenario's diagram and README says which component noticed the problem, so the architecture is taught through the failures, not as a lecture.


---

## Section 1: Architecture and Pod lifecycle
How a Pod comes to life, and which component notices when it does not: scheduler, API server, kubelet, container runtime.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **1.1** (K01) | [The whiteboard that never starts](01-excalidraw-pending/README.md) | scheduler, requests | *We asked for a whiteboard. Kubernetes heard "a data centre".* |
| **1.2** (K02) | [The one-letter typo](02-image-typo/README.md) | kubelet + container runtime (image pull) | *One missing letter. Kubernetes tries, waits, tries again… forever.* |
| **1.3** (K03) | [The loop](03-showdown-crashloop/README.md) | Pod lifecycle, restart policy | *It starts. It dies. It starts. It dies. Welcome to the loop.* |
| **1.4** (K26) | [Stuck before it starts](26-showdown-init-stuck/README.md) | init containers, Pod phases | *Cats vs Dogs is waiting for its database. Forever.* |
| **1.5** (K37) | [The Pod that will not leave](37-pod-that-will-not-leave/README.md) | API server, finalizers, termination | *You said delete. Kubernetes said yes. The Pod did not get the message.* |

**Exercises for this section** (self-paced, with hints, in the second slot):
- [K17 · The trainer wants a GPU](17-ai-trainer-needs-gpu/README.md): GPU request: Pending, node selection
- [K18 · One replica too many](18-whoami-anti-affinity/README.md): anti-affinity: one replica too many
- [K29 · Half ready](29-log-sidecar-half-ready/README.md): multi-container Pod: half ready

---

## Section 2: Workloads
Deployments and ReplicaSets, StatefulSets, DaemonSets, Jobs and CronJobs: the right controller for the right job.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **2.1** (K32) | [The label on the wrong object](32-label-on-the-wrong-object/README.md) | Deployment, ReplicaSet, labels on the template | *The label is right there. Kubernetes is looking somewhere else.* |
| **2.2** (K15) | [The stall that opens one at a time](15-stall-that-opens-one-at-a-time/README.md) ⏳ | StatefulSet: ordered start, stable names | *Three stalls were ordered. One opened. The other two are not even built.* |
| **2.3** (K16) | [The watchman who skipped a gate](16-watchman-skipped-a-gate/README.md) | DaemonSet: one per node, taints | *A watchman was posted at every gate. One gate has nobody. Kubernetes says everything is fine.* |
| **2.4** (K28) | [The nightly reset that gave up](28-leaderboard-reset-job/README.md) | Job: retries, backoffLimit | *The midnight reset ran. Three times. Then gave up.* |
| **2.5** (K24) | [The nightly reset that never started](24-nightly-reset-that-never-started/README.md) ⏳ | CronJob: schedule, suspend | *It is scheduled for every minute. It has been "every minute" for three weeks. Nothing has run.* |

---

## Section 3: Services, ingress and networking
How traffic finds Pods: Services, DNS, ingress routing and Network Policies.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **3.1** (K04) | [Running is not reachable](04-it-tools-no-endpoints/README.md) | Service selector and endpoints | *Every Pod is Running. Every request fails.* |
| **3.2** (K05) | [Right Pod, wrong door](05-excalidraw-wrong-port/README.md) | port and targetPort | *Endpoints exist. The Pod is fine. Still: connection refused.* |
| **3.3** (K12) | [Same cluster, same name, "never heard of it"](12-showdown-dns-namespaces/README.md) | DNS across namespaces | *The Redis is running. The app is running. And the app swears Redis does not exist.* |
| **3.4** (K33) | [The route to the wrong stall](33-route-to-the-wrong-stall/README.md) ⏳ | Gateway API / Ingress routing | *One front door, two paths. One path leads to a stall that does not exist.* |
| **3.5** (K13) | [Security hardened the network. Now nothing can find anything.](13-lockdown-blocks-dns/README.md) | NetworkPolicy and DNS | *Security locked the app down so it can only talk to Redis. And now the app cannot even find Redis.* |

---

## Section 4: Configuration, storage and security
ConfigMaps and Secrets, persistent storage, RBAC and Pod security.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **4.1** (K23) | [Dark mode is on. The site is still white.](23-dark-mode-not-applied/README.md) | ConfigMap: env vs live | *Dark mode is ON in the config. The site is still blinding white.* |
| **4.2** (K09) | [The container that never got created](09-adminer-missing-secret/README.md) | Secret: missing key | *The database tool won't even start. No logs. Nothing.* |
| **4.3** (K10) | [The task board is waiting for a disk that will never arrive](10-kanboard-pvc-pending/README.md) ⏳ | PersistentVolumeClaim, StorageClass | *The Pod isn't crashing. It isn't even starting. It's waiting for a disk that doesn't exist.* |
| **4.4** (K14) | [The bot has an ID card, but the door stays shut](14-leaderboard-bot-forbidden/README.md) | RBAC, ServiceAccounts | *The bot has a valid ID card. The API still says: not allowed.* |
| **4.5** (K21) | [The rule that turned the lights off](21-notice-board-runasnonroot/README.md) | securityContext: runAsNonRoot | *Security turned on one rule. The notice board went dark.* |

**Exercises for this section** (self-paced, with hints, in the second slot):
- [K22 · Locked down and locked out](22-notice-board-readonly-fs/README.md): read-only root filesystem
- [K43 · The maintenance van wants the master key](43-maintenance-van-wants-the-master-key/README.md): Pod Security: baseline
- [K44 · The checklist](44-the-checklist/README.md): Pod Security: restricted checklist
- [K45 · The locked-down kitchen](45-the-locked-down-kitchen/README.md): Pod Security: boss

---

## Section 5: Scaling, self-healing and releases
Probes and self-healing, autoscaling, rolling updates and deployment strategies.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **5.1** (K06) | [Running, healthy, and never any visitors](06-kanboard-never-ready/README.md) | readiness probe | *It's running. It's healthy. It just never gets any visitors.* |
| **5.2** (K07) | [The impatient guard](07-showdown-slow-start/README.md) | liveness probe and slow start | *A perfectly healthy app keeps getting killed, again and again, every few seconds.* |
| **5.3** (K25) | [The autoscaler that shrugs](25-showdown-hpa-not-scaling/README.md) ⏳ | HorizontalPodAutoscaler | *Traffic is pouring in. The autoscaler shrugs: "unknown".* |
| **5.4** (K11) | [The Friday release](11-showdown-bad-rollout/README.md) | rolling update held back, rollback | *Friday, 6 PM. The release goes out. Nobody notices… because Kubernetes saved you.* |
| **5.5** (K08) | [No error, no goodbye (Kubernetes edition)](08-ai-trainer-oomkilled/README.md) ⏳ | resource limits, OOM kill | *Your AI model was training. Then it vanished. No error. No goodbye. And Kubernetes keeps bringing it back to die again.* |

**Exercises for this section** (self-paced, with hints, in the second slot):
- [K34 · The doorbell on the wrong door](34-doorbell-on-the-wrong-door/README.md): readiness: wrong door
- [K35 · The biryani that needs 20 seconds](35-biryani-that-needs-20-seconds/README.md): liveness: too early
- [K36 · Two probes, two mistakes](36-two-probes-two-mistakes/README.md): two probes, two faults
- [K39 · The robot that cannot move the stalls](39-robot-that-cannot-move-the-stalls/README.md): PodDisruptionBudget
- [K41 · The autoscaler pointing at nobody](41-autoscaler-pointing-at-nobody/README.md): autoscaler: wrong target

---

## Section 6: Namespaces, quotas, Helm and troubleshooting
Namespaces and resource quotas, Helm releases, labels and annotations, and the habit of finding what really ran.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **6.1** (K38) | [Applied here, looking there](38-applied-here-looking-there/README.md) | namespaces and kubectl context | *The deploy said "created". The cluster says "No resources found". Both are telling the truth.* |
| **6.2** (K19) | [The deploy that created nothing](19-hackathon-quota/README.md) | ResourceQuota | *The deploy succeeded. Kubernetes created… nothing.* |
| **6.3** (K27) | [The upgrade that broke the stall](27-upgrade-that-broke-the-stall/README.md) ⏳ | Helm: release, history, rollback | *Helm said "deployed". Helm was not lying. Helm was not helping either.* |
| **6.4** (K31) | [Two stalls, one signboard](31-two-stalls-one-signboard/README.md) | labels, selectors, annotations | *Some customers get hot chai. Some get… yesterday's.* |
| **6.5** (K20) | [The limit nobody wrote](20-surprise-limitrange-oom/README.md) | LimitRange: what ran vs what you wrote | *"Nobody set a memory limit. The app still got killed for exceeding it."* |

**Exercises for this section** (self-paced, with hints, in the second slot):
- [K40 · The stall that asked for too much](40-stall-that-asked-for-too-much/README.md): LimitRange maximum
- [K42 · Who gets evicted first](42-who-gets-evicted-first/README.md): QoS classes and eviction order

---

## 🏁 The finale and the projects (second slot)
- **Finale: [K30 · The Friday 5 PM outage (the finale)](30-friday-5pm-outage/README.md)**: *Friday, 5 PM. Three things broke. Nobody knows that yet.* Three faults at once, about 30 minutes. Run it after the six sections, when the class has met each kind of fault alone.
- **Two projects** (lab exercises 5 and 6): [Project 1, Canteen Rush](../projects/project-1-canteen-rush/README.md) (deploy, scale, update) and [Project 2, Canteen Rush packaged](../projects/project-2-canteen-helm/README.md) (config, secrets, Jobs, CronJobs, Helm). Students then build their own.

**Every scenario has a `./check.sh`** in its folder. Run it whenever you like: it only looks, never changes anything, and tells you in one line whether you are done.

Each scenario lives in its own namespace named `k-NN-<slug>` (K12 uses two, K13 also creates a short-lived `k-13-probe`), so nothing touches your lab work. All images and sizes are in [IMAGES.md](IMAGES.md).

## How a session runs

1. **Instructor explains**: read the story and the concept in the scenario's `README.md`.
2. **Break it**: `cd break && ./break.sh`
3. **Predict, then investigate by hand.** Every scenario opens its investigation with a **predict-first** box (a few seconds in a 4-minute demo, a full minute in an exercise): say what you expect before you type anything. Then the class types the commands from the README. `break.sh` never explains the cause, that is the class's job. In scenarios with a small `visitor` Pod (most of them; the README says when) open a **second terminal** and run `kubectl logs -f visitor -n <namespace>` (the README gives the exact line) to watch the app fail as a user sees it. (K25 has no visitor: watch the autoscaler instead with `kubectl get hpa -n k-25-hpa -w`.)
4. **Meet the tempting wrong fix.** Each scenario names the fix everyone reaches for first (restart it, scale it up, switch the rule off) and shows why it does not work. Then **fix it**: `cd ../fix && ./fix.sh`. If the visitor log is open, the live ❌ → ✅ moment is the best part of the demo.
5. **Verify by hand**: the class checks it really works. `fix.sh` does not verify for you. To open an app, use a **second terminal**:
   ```bash
   kubectl port-forward -n <namespace> svc/<service> 92NN:<port>
   ```
   The scenario README prints the exact line (for example K07: `kubectl port-forward -n k-07-slow-start svc/showdown 9207:80`). Then open `http://localhost:92NN` on a laptop. On a playground, add `--address 0.0.0.0` and open the URL for port `92NN`. Press **Ctrl+C** in that terminal to stop it. Several scenarios (for example K08, K14, K16, K24 and K28) have no web page: you verify them in the terminal.

   **Why the laptop command has no `--address 0.0.0.0`:** without it, `port-forward` listens on `localhost` only. With it, anyone on the same network (venue Wi-Fi) could open your app, and Kanboard's default login is `admin` / `admin`. A playground needs `--address 0.0.0.0` because its URL proxy reaches the app from outside the terminal. Keep `-n <namespace>` right after `port-forward`: `cleanup.sh` finds leftovers by that text.
6. **Clean up**: `cd .. && ./cleanup.sh`

Every `break.sh` cleans up first, so you can run it again and again. Every script works from any folder.

## Platform notes

| Where | What to know |
|-------|--------------|
| kind | Works. The default network add-on of recent kind versions enforces NetworkPolicy, so K13 runs. The default StorageClass is `standard`. |
| minikube | Works with a default StorageClass (`standard`). A plain `minikube start` may **not enforce NetworkPolicy**, so K13 stops with a clear message: start it with `minikube start --cni=calico` for K13. |
| Docker Desktop (Kubernetes enabled) | Works. The StorageClass is called `hostpath`. NetworkPolicy is often **not enforced**, so K13 may stop with its message (that is the check working, not a bug). |
| Killercoda, iximiuz | Supported. Open the apps through the platform's "traffic / ports" link for `92NN`. Both should enforce NetworkPolicy (K13's `break.sh` checks before it breaks anything). |
| Windows | Use **WSL2** (Ubuntu) and run everything inside it. Git Bash is not enough: the scripts use `pkill` and `pgrep`, which it lacks. |
| Play with Docker | **No Kubernetes there.** Use the Docker scenarios instead, or a Kubernetes playground. |

Things to know before you start:

- **Check your cluster first.** `kubectl config current-context` shows which cluster you are about to break. The scenarios create things in their own `k-NN-...` namespaces, with two exceptions: K16 (a taint on the nodes) and K25 (metrics-server, only if missing). Their `cleanup.sh` reverts exactly that. Break the right cluster on purpose.
- **K10 needs a default StorageClass.** `kubectl get storageclass` must show one marked `(default)`. K10's fix is to stop asking for the missing `fast-ssd` class and use that default.
- **K01, K02 and K10 download their app at fix time**, because the Pod never starts while it is broken (K01, K02: Excalidraw; K10: Kanboard). On a cold cluster the fix waits on that download (the first time it can take up to a minute or two): preload it or run the scenario once before class (see the checklist below).
- **K13 needs a cluster that enforces NetworkPolicy**, and checks it first (a throwaway `k-13-probe` namespace, deleted straight after). If your cluster ignores policies, it stops with a clear message instead of showing a fake outage.
- **K16 changes a node, not just a namespace.** It puts a taint (`z2h-vip`) on one node, so always run its `cleanup.sh` (it removes the taint again; `break.sh` also starts clean). Do not skip it, or the next scenario sees a tainted cluster. On a one-node cluster the taint lands on that node and the watchman is missing everywhere; the lesson is the same.
- **K25 installs metrics-server only if your cluster has none**, and removes it again afterwards only if it installed it. Run K25 on its own (not alongside other scenarios): adding or removing metrics-server briefly changes the cluster's API list.
- **K27 needs Helm** (`helm version` must work). **K33 needs a Gateway controller**: install it once with `./scripts/install-gateway.sh` (about 1 GB of memory). Both say so and stop if they are missing.
- **K24 takes up to a minute and a half to show its fix**, because a CronJob only fires on the minute. Start the fix, then talk while you wait.
- **K30 is the finale.** Three faults at once, three tracks, about 25 to 30 minutes. Run it after the six sections, when the class has seen each kind of fault on its own.
- **K37 leaves a Pod that cannot be deleted** on purpose (a finalizer). Its `cleanup.sh` lifts the finalizer first so the namespace can go; run it, don't just delete the namespace.
- **K38 changes your kubeconfig's current namespace** (that is its fix). `./cleanup.sh` puts it back, and only if this scenario was the one that set it. If you are unsure, `kubectl config view --minify -o jsonpath='{..namespace}'` shows where you are looking.
- **K43 to K45 label their namespace with a Pod Security level.** Pod Security Admission is built into Kubernetes 1.25 and later, so it needs nothing installed. K45 also pulls two small nginx images.
- **K42 only reads Pod classes.** It never starves the node, so it is safe on a one-node cluster.
- **K41 needs no metrics-server.** The autoscaler's complaint is about its target, which every cluster can show.
- **K39 sends one eviction request, not a drain.** A real `kubectl drain` would cordon a whole node, which is unsafe on a one-node Docker Desktop or minikube. The robot asks for one Pod only, so it is safe everywhere.
- **Scenarios behave the same on 1 node and 3 nodes** (minikube and Docker Desktop are one node; the course's kind config is three).

Scripts need only `bash`, `kubectl`, `curl` and ordinary Unix tools. No `jq`. Helm is needed for K27 only, and the Gateway controller for K33 only.

## 🆘 PANIC CARD (when something goes wrong on stage)

Stay calm. Everything lives in the `k-NN-...` namespaces, except K16's node taint and K25's metrics-server (see above). In this order:

1. **Reset the scenario:** `./cleanup.sh` (from the scenario folder). It is safe at any time, even if nothing is running, and it waits until the namespace is really gone.
2. **Look at what is left:** `kubectl get ns | grep '^k-'`. Anything listed is a scenario namespace; delete one with `kubectl delete ns <name>`.
3. **Port already in use?** An old port-forward is still running: `pkill -f "port-forward -n k-"` (or press Ctrl+C in its terminal).
4. **Run it again:** `./break.sh` again. It starts clean every time.
5. **Pods stuck in Pending in every scenario?** Look for a leftover K16 taint: `kubectl describe nodes | grep -A2 Taints`. If you see `z2h-vip`, run `kubernetes/scenarios/16-watchman-skipped-a-gate/cleanup.sh` (or `kubectl taint nodes --all z2h-vip-`).
6. **Still odd? Reset everything:** `./labs.sh k8s clean` from the repo root. It runs every scenario's `cleanup.sh` against your current cluster.

`The connection to the server ... was refused` or `no cluster`? Start Docker Desktop / minikube / kind, check `kubectl config current-context`, then step 4.

## Instructor preload checklist

- [ ] **Check which cluster you are on:** `kubectl config current-context`. The preload loads images into the cluster of the **current** context, so make sure it is the demo cluster.
- [ ] **The day before**, on good Wi-Fi: `./kubernetes/scenarios/preload.sh`. It pulls every image in [IMAGES.md](IMAGES.md) (about 300 MB download) with Docker, and prints ✅/❌ per image and a total. If the current context is `kind-<name>` it also runs `kind load docker-image` into that cluster, and for `minikube` it runs `minikube image load`. Other clusters (Docker Desktop, Killercoda, iximiuz) download images when a Pod first starts, so run each scenario once there instead.
- [ ] **Then run every scenario once** (break, fix, cleanup), so you have seen each output on your own machine.
- [ ] On the morning: `kubectl get ns | grep '^k-'` prints nothing (or run `./labs.sh k8s clean`), and no leftover `kubectl port-forward` is running.

## Playground dry-run checklist

### Run the automated dry run (about 45 minutes)

Do this once on every platform you will teach from, a day or more before the event. It runs each scenario twice (break, check broken, fix, check fixed, cleanup) and prints ✅ or ❌ per scenario.

> ⚠️ Use a cluster you can throw away (a fresh playground, a new minikube or kind cluster). The dry run deletes and recreates every `k-NN-…` namespace, and K16 (a node taint) and K25 (metrics-server) change the cluster (they undo it at the end).

1. Get the repo onto that machine and open a terminal in it:
   ```bash
   git clone https://github.com/vellankikoti/docker-k8s-zero-to-hero.git && cd docker-k8s-zero-to-hero
   ```
2. Check the tools (`kubectl`, `bash`, `curl`; Docker only for the preload). The last lines should say `0 failed`; lines marked `•` are only tips:
   ```bash
   ./scripts/check-prereqs.sh
   ```
3. Check that `kubectl` talks to the cluster you mean to test, and note its exact name:
   ```bash
   kubectl config current-context
   ```
4. **Tell the test harness that this cluster may be used.** By default it refuses every cluster except the build machine's throwaway `kind-z2h-test`, so that it can never touch a real cluster by mistake. You unlock it for one cluster by naming it exactly:
   ```bash
   export Z2H_DRY_RUN_CONTEXT="$(kubectl config current-context)"
   ```
5. Run everything except K16, K25 and K33 (it needs the Gateway controller, so give it its own run). The first group takes the longest, so start it before a coffee:
   ```bash
   ./tests/scenarios/k8s.sh 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 17 18 19 20 21 22 23 24 26 27 28 29 30 31 32 34 35 36 37 38 39 40 41 42 43 44 45
   ```
6. Run K16, K25 and K33 on their own, one after the other (K16 taints a node, K25 installs metrics-server only if the cluster has none, K33 installs the Gateway controller if needed):
   ```bash
   ./tests/scenarios/k8s.sh 16
   ```
   ```bash
   ./tests/scenarios/k8s.sh 25
   ```
   ```bash
   ./tests/scenarios/k8s.sh 33
   ```
7. All ✅ in the summaries means you can tick that platform's column in the table below. Lock the harness again and clean up:
   ```bash
   unset Z2H_DRY_RUN_CONTEXT
   ```
   ```bash
   ./labs.sh k8s clean
   ```

**If you see `Refusing to run`:** step 4 was skipped, or the current context changed since. Repeat steps 3 and 4. The harness only runs when `Z2H_DRY_RUN_CONTEXT` equals the current context exactly.

**If a scenario shows ❌:** run it again on its own (for example `./tests/scenarios/k8s.sh 13`). A second ❌ is real. The lines just above `FAILED at step:` say which check failed. Then run that scenario by hand from its README to see what the room would see. The usual causes are in "Known platform-sensitive scenarios" below (for example, K13 needs a cluster that enforces NetworkPolicy).

### Results

Tick each cell after you have run the whole scenario (break, fix, cleanup) on that platform. The build machine tested **kind only** (3 nodes and 1 node, on macOS arm64), so the kind column is ticked; every other cell is still to be ticked by an instructor.

| Scenario | kind | minikube | Docker Desktop | Killercoda | iximiuz | WSL2 |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|
| K01 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K02 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K03 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K04 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K05 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K06 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K07 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K08 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K09 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K10 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K11 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K12 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K13 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K14 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K15 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K16 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K17 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K18 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K19 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K20 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K21 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K22 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K23 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K24 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K25 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K26 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K27 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K28 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K29 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K30 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K31 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K32 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K33 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K34 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K35 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K36 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K37 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K38 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K39 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K40 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K41 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K42 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K43 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K44 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K45 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |

**Known platform-sensitive scenarios.** Look at these first:

- **K07 and K11 timing:** K07's app takes about 20 seconds to wake up and K11's broken release needs a moment to be refused by its readiness check. On a slow or busy node the restarts and the "timed out" moment come a little later than the README says. Wait for the visible symptom before you start explaining.
- **K08 `OOMKilled` vs `Error`:** the kill is the same, but on some clusters and container runtimes the `STATUS` column shows `Error` instead of `OOMKilled`. Check `kubectl describe pod` (the `Last State` shows the reason and exit code 137) before the class.
- **K10 StorageClass names:** `standard` on kind and minikube, `hostpath` on Docker Desktop, `local-path` on Killercoda. A default class must exist. K10 also downloads Kanboard at fix time (and K01, K02 download Excalidraw).
- **K12 and K13 DNS error wording:** the exact message from the failed name lookup (`Name or service not known`, `Temporary failure in name resolution`, ...) differs between images and cluster DNS versions. The idea (the name does not resolve) is the same.
- **K13 enforcement:** needs a NetworkPolicy-enforcing cluster. Run it on your platform before class. If it stops with its "not enforced" message, switch cluster (minikube: `--cni=calico`) or skip K13.

Found a difference? Write it next to the scenario's README commands, so the next instructor knows.

➡️ Back to the [Kubernetes track](../README.md)
