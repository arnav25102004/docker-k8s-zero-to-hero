# 🔥 Kubernetes break-and-fix scenarios

**30 core scenarios in six sections, plus 30 exercises (five per section, one of them the finale).** Each core scenario is a 4-minute live demo that **breaks something in a cluster on purpose**: the class investigates by hand with `kubectl`, then a fix script repairs it. Every scenario has its own folder with a story, a diagram, the concept, the commands to type, a `check.sh` and takeaways.

> **Scenarios vs labs.** Scenarios are named **S1.1 to S6.5** (section, then number) and live in the six section folders here. They are not the labs K00–K19 in the [Kubernetes track](../README.md).

> ### 🧰 Install these two things first (once)
> **1. metrics-server, right after your cluster is up.** Without it there is no `kubectl top`, the autoscaler (S5.3) has nothing to read, and the K01 lab tour is half blind.
> ```bash
> ./scripts/install-metrics-server.sh
> ```
> **2. (Optional) Prometheus and Grafana**, to watch every incident as a graph and an alert. Many scenarios have a short "👀 See it in monitoring" tip that needs it. It needs `helm` and about 2 GB of free memory; the first run takes about five minutes. Lab [K19](../19-observability/README.md) teaches it.
> ```bash
> ./scripts/install-monitoring.sh
> ```
> Every scenario works without it. For a live picture of the cluster as you break it, the [Kubilitics](https://kubilitics.com/) desktop app helps too ([K01, Step 9](../01-cluster-tour/README.md)).

## The plan: 6 sections, 30 scenarios, 120 minutes

Thirty scenarios, grouped into **six sections of five**. Open a section folder and the scenarios are numbered 1 to 5, in teaching order. Each is a **4-minute live demo**: about 20 seconds of story, 40 seconds to break it, 90 seconds to find the cause with the class, 40 seconds to fix it, 30 seconds for the one-line lesson. Six sections × five scenarios × four minutes = **two hours, non-stop**. The exercises, the finale and the two projects fit the second two-hour slot.

> 🕐 **Four minutes only works if the next scenario is already broken.** Open a second terminal and run the *next* `break.sh` while you talk through the current lesson (each scenario has its own namespace). Scenarios marked ⏳ take longer to set up or to fix: start those one scenario early.

**How to read an id:** `S2.3` is Section 2, scenario 3, in `kubernetes/scenarios/2-workloads/3-…`. `S5.x1` is Section 5, exercise 1, in that section's `exercises/` folder (`5-…/exercises/1-…`). Every section has at least five exercises.


---

## Section 1: Architecture and Pod lifecycle
How a Pod comes to life, and which component notices when it does not: scheduler, API server, kubelet, container runtime.
**Syllabus topics:** Kubernetes architecture, control-plane and worker-node components, container runtimes, Pods and lifecycle management.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S1.1** | [The whiteboard that never starts](1-architecture-and-pod-lifecycle/1-excalidraw-pending/README.md) | scheduler, requests | *We asked for a whiteboard. Kubernetes heard "a data centre".* |
| **S1.2** | [The one-letter typo](1-architecture-and-pod-lifecycle/2-image-typo/README.md) | kubelet + container runtime (image pull) | *One missing letter. Kubernetes tries, waits, tries again… forever.* |
| **S1.3** | [The loop](1-architecture-and-pod-lifecycle/3-showdown-crashloop/README.md) | Pod lifecycle, restart policy | *It starts. It dies. It starts. It dies. Welcome to the loop.* |
| **S1.4** | [Stuck before it starts](1-architecture-and-pod-lifecycle/4-showdown-init-stuck/README.md) | init containers, Pod phases | *Cats vs Dogs is waiting for its database. Forever.* |
| **S1.5** | [The Pod that will not leave](1-architecture-and-pod-lifecycle/5-pod-that-will-not-leave/README.md) | API server, finalizers, termination | *You said delete. Kubernetes said yes. The Pod did not get the message.* |

**Exercises for this section** (self-paced, with hints, in the second slot; in each section's `exercises/` folder):
- [S1.x1 · The trainer wants a GPU](1-architecture-and-pod-lifecycle/exercises/1-ai-trainer-needs-gpu/README.md): GPU request: Pending, node selection
- [S1.x2 · One replica too many](1-architecture-and-pod-lifecycle/exercises/2-whoami-anti-affinity/README.md): anti-affinity: one replica too many
- [S1.x3 · Half ready](1-architecture-and-pod-lifecycle/exercises/3-log-sidecar-half-ready/README.md): multi-container Pod: half ready
- [S1.x4 · Follow a Pod's birth](1-architecture-and-pod-lifecycle/exercises/4-follow-a-pods-birth/README.md): the scheduler, the kubelet and the container runtime, read from Events
- [S1.x5 · Read the cluster you are standing on](1-architecture-and-pod-lifecycle/exercises/5-read-the-cluster-you-stand-on/README.md): control-plane components, node components, DaemonSets in kube-system, kubelet and runtime versions

---

## Section 2: Workloads
Deployments and ReplicaSets, StatefulSets, DaemonSets, Jobs and CronJobs: the right controller for the right job.
**Syllabus topics:** Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs and CronJobs.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S2.1** | [The label on the wrong object](2-workloads/1-label-on-the-wrong-object/README.md) | Deployment, ReplicaSet, labels on the template | *The label is right there. Kubernetes is looking somewhere else.* |
| **S2.2** | [The stall that opens one at a time](2-workloads/2-stall-that-opens-one-at-a-time/README.md) ⏳ | StatefulSet: ordered start, stable names | *Three stalls were ordered. One opened. The other two are not even built.* |
| **S2.3** | [The watchman who skipped a gate](2-workloads/3-watchman-skipped-a-gate/README.md) | DaemonSet: one per node, taints | *A watchman was posted at every gate. One gate has nobody. Kubernetes says everything is fine.* |
| **S2.4** | [The nightly reset that gave up](2-workloads/4-leaderboard-reset-job/README.md) | Job: retries, backoffLimit | *The midnight reset ran. Three times. Then gave up.* |
| **S2.5** | [The nightly reset that never started](2-workloads/5-nightly-reset-that-never-started/README.md) ⏳ | CronJob: schedule, suspend | *It is scheduled for every minute. It has been "every minute" for three weeks. Nothing has run.* |

**Exercises for this section** (self-paced, with hints, in the second slot; in each section's `exercises/` folder):
- [S2.x1 · Delete the owner, keep the Pods](2-workloads/exercises/1-delete-the-owner-keep-the-pods/README.md): ReplicaSet, ownerReferences, selectors, --cascade=orphan
- [S2.x2 · The Pod that comes back with the same name](2-workloads/exercises/2-pod-that-comes-back-with-the-same-name/README.md): StatefulSet, stable Pod names, headless Service, ordered start and stop
- [S2.x3 · A watchman for chosen gates only](2-workloads/exercises/3-watchman-for-chosen-gates-only/README.md): DaemonSet, nodeSelector, node labels
- [S2.x4 · Six tasks, two hands](2-workloads/exercises/4-six-tasks-two-hands/README.md): Job, completions, parallelism, restartPolicy
- [S2.x5 · Run the nightly job right now](2-workloads/exercises/5-run-the-nightly-job-right-now/README.md): CronJob, create job --from, suspend, concurrencyPolicy

---

## Section 3: Services, ingress and networking
How traffic finds Pods: Services, DNS, ingress routing and Network Policies.
**Syllabus topics:** Services and ingress routing, Kubernetes networking and network policies.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S3.1** | [Running is not reachable](3-services-ingress-and-networking/1-it-tools-no-endpoints/README.md) | Service selector and endpoints | *Every Pod is Running. Every request fails.* |
| **S3.2** | [Right Pod, wrong door](3-services-ingress-and-networking/2-excalidraw-wrong-port/README.md) | port and targetPort | *Endpoints exist. The Pod is fine. Still: connection refused.* |
| **S3.3** | [Same cluster, same name, "never heard of it"](3-services-ingress-and-networking/3-showdown-dns-namespaces/README.md) | DNS across namespaces | *The Redis is running. The app is running. And the app swears Redis does not exist.* |
| **S3.4** | [The route to the wrong stall](3-services-ingress-and-networking/4-route-to-the-wrong-stall/README.md) ⏳ | Gateway API / Ingress routing | *One front door, two paths. One path leads to a stall that does not exist.* |
| **S3.5** | [Security hardened the network. Now nothing can find anything.](3-services-ingress-and-networking/5-lockdown-blocks-dns/README.md) | NetworkPolicy and DNS | *Security locked the app down so it can only talk to Redis. And now the app cannot even find Redis.* |

**Exercises for this section** (self-paced, with hints, in the second slot; in each section's `exercises/` folder):
- [S3.x1 · Three ways into one Service](3-services-ingress-and-networking/exercises/1-three-ways-in/README.md): ClusterIP, port-forward, NodePort, port vs targetPort
- [S3.x2 · Who is behind the Service?](3-services-ingress-and-networking/exercises/2-who-is-behind-the-service/README.md): EndpointSlices, label selectors, isolating a Pod for debugging
- [S3.x3 · Where did these variables come from?](3-services-ingress-and-networking/exercises/3-where-did-these-variables-come-from/README.md): Service environment variables, Pod start order, DNS as the better way
- [S3.x4 · Same name, another namespace](3-services-ingress-and-networking/exercises/4-same-name-another-namespace/README.md): cluster DNS, search domains, namespaces, FQDN
- [S3.x5 · Lock the vault, then give one friend the key](3-services-ingress-and-networking/exercises/5-lock-the-vault/README.md): NetworkPolicy, default deny, podSelector, allow rules

---

## Section 4: Configuration, storage and security
ConfigMaps and Secrets, persistent storage, RBAC and Pod security.
**Syllabus topics:** ConfigMaps and Secrets, persistent storage, RBAC, security policies.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S4.1** | [Dark mode is on. The site is still white.](4-config-storage-and-security/1-dark-mode-not-applied/README.md) | ConfigMap: env vs live | *Dark mode is ON in the config. The site is still blinding white.* |
| **S4.2** | [The container that never got created](4-config-storage-and-security/2-adminer-missing-secret/README.md) | Secret: missing key | *The database tool won't even start. No logs. Nothing.* |
| **S4.3** | [The task board is waiting for a disk that will never arrive](4-config-storage-and-security/3-kanboard-pvc-pending/README.md) ⏳ | PersistentVolumeClaim, StorageClass | *The Pod isn't crashing. It isn't even starting. It's waiting for a disk that doesn't exist.* |
| **S4.4** | [The bot has an ID card, but the door stays shut](4-config-storage-and-security/4-leaderboard-bot-forbidden/README.md) | RBAC, ServiceAccounts | *The bot has a valid ID card. The API still says: not allowed.* |
| **S4.5** | [The rule that turned the lights off](4-config-storage-and-security/5-notice-board-runasnonroot/README.md) | securityContext: runAsNonRoot | *Security turned on one rule. The notice board went dark.* |

**Exercises for this section** (self-paced, with hints, in the second slot; in each section's `exercises/` folder):
- [S4.x1 · Locked down and locked out](4-config-storage-and-security/exercises/1-notice-board-readonly-fs/README.md): read-only root filesystem
- [S4.x2 · The maintenance van wants the master key](4-config-storage-and-security/exercises/2-maintenance-van-wants-the-master-key/README.md): Pod Security: baseline
- [S4.x3 · The checklist](4-config-storage-and-security/exercises/3-the-checklist/README.md): Pod Security: restricted checklist
- [S4.x4 · The locked-down kitchen](4-config-storage-and-security/exercises/4-the-locked-down-kitchen/README.md): Pod Security: boss
- [S4.x5 · The file that outlived the Pod](4-config-storage-and-security/exercises/5-the-file-that-outlived-the-pod/README.md): PersistentVolumeClaim, volumes, StorageClass, data outliving a Pod

---

## Section 5: Scaling, self-healing and releases
Probes and self-healing, autoscaling, rolling updates and deployment strategies.
**Syllabus topics:** health probes and self-healing, autoscaling, rolling updates and deployment strategies.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S5.1** | [Running, healthy, and never any visitors](5-scaling-self-healing-and-releases/1-kanboard-never-ready/README.md) | readiness probe | *It's running. It's healthy. It just never gets any visitors.* |
| **S5.2** | [The impatient guard](5-scaling-self-healing-and-releases/2-showdown-slow-start/README.md) | liveness probe and slow start | *A perfectly healthy app keeps getting killed, again and again, every few seconds.* |
| **S5.3** | [The autoscaler that shrugs](5-scaling-self-healing-and-releases/3-showdown-hpa-not-scaling/README.md) ⏳ | HorizontalPodAutoscaler | *Traffic is pouring in. The autoscaler shrugs: "unknown".* |
| **S5.4** | [The Friday release](5-scaling-self-healing-and-releases/4-showdown-bad-rollout/README.md) | rolling update held back, rollback | *Friday, 6 PM. The release goes out. Nobody notices… because Kubernetes saved you.* |
| **S5.5** | [No error, no goodbye (Kubernetes edition)](5-scaling-self-healing-and-releases/5-ai-trainer-oomkilled/README.md) ⏳ | resource limits, OOM kill | *Your AI model was training. Then it vanished. No error. No goodbye. And Kubernetes keeps bringing it back to die again.* |

**Exercises for this section** (self-paced, with hints, in the second slot; in each section's `exercises/` folder):
- [S5.x1 · The doorbell on the wrong door](5-scaling-self-healing-and-releases/exercises/1-doorbell-on-the-wrong-door/README.md): readiness: wrong door
- [S5.x2 · The biryani that needs 20 seconds](5-scaling-self-healing-and-releases/exercises/2-biryani-that-needs-20-seconds/README.md): liveness: too early
- [S5.x3 · Two probes, two mistakes](5-scaling-self-healing-and-releases/exercises/3-two-probes-two-mistakes/README.md): two probes, two faults
- [S5.x4 · The robot that cannot move the stalls](5-scaling-self-healing-and-releases/exercises/4-robot-that-cannot-move-the-stalls/README.md): PodDisruptionBudget
- [S5.x5 · The autoscaler pointing at nobody](5-scaling-self-healing-and-releases/exercises/5-autoscaler-pointing-at-nobody/README.md): autoscaler: wrong target

---

## Section 6: Namespaces, quotas, Helm and troubleshooting
Namespaces and resource quotas, Helm releases, labels and annotations, and the habit of finding what really ran.
**Syllabus topics:** namespaces and resource quotas, Helm charts, labels and annotations, Kubernetes troubleshooting.

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S6.1** | [Applied here, looking there](6-namespaces-quotas-helm-and-troubleshooting/1-applied-here-looking-there/README.md) | namespaces and kubectl context | *The deploy said "created". The cluster says "No resources found". Both are telling the truth.* |
| **S6.2** | [The deploy that created nothing](6-namespaces-quotas-helm-and-troubleshooting/2-hackathon-quota/README.md) | ResourceQuota | *The deploy succeeded. Kubernetes created… nothing.* |
| **S6.3** | [The upgrade that broke the stall](6-namespaces-quotas-helm-and-troubleshooting/3-upgrade-that-broke-the-stall/README.md) ⏳ | Helm: release, history, rollback | *Helm said "deployed". Helm was not lying. Helm was not helping either.* |
| **S6.4** | [Two stalls, one signboard](6-namespaces-quotas-helm-and-troubleshooting/4-two-stalls-one-signboard/README.md) | labels, selectors, annotations | *Some customers get hot chai. Some get… yesterday's.* |
| **S6.5** | [The limit nobody wrote](6-namespaces-quotas-helm-and-troubleshooting/5-surprise-limitrange-oom/README.md) | LimitRange: what ran vs what you wrote | *"Nobody set a memory limit. The app still got killed for exceeding it."* |

**Exercises for this section** (self-paced, with hints, in the second slot; in each section's `exercises/` folder):
- [S6.x1 · The stall that asked for too much](6-namespaces-quotas-helm-and-troubleshooting/exercises/1-stall-that-asked-for-too-much/README.md): LimitRange maximum
- [S6.x2 · Who gets evicted first](6-namespaces-quotas-helm-and-troubleshooting/exercises/2-who-gets-evicted-first/README.md): QoS classes and eviction order
- [S6.x3 · Roll a release back](6-namespaces-quotas-helm-and-troubleshooting/exercises/3-roll-a-release-back/README.md): helm install, upgrade, history, rollback, values
- [S6.x4 · Find it by label](6-namespaces-quotas-helm-and-troubleshooting/exercises/4-find-it-by-label/README.md): labels, selectors (equality and set-based), annotations, kubectl -l

---

## 🏁 The finale and the projects (second slot)
- **Finale: [S6.x5 · The Friday 5 PM outage (the finale)](6-namespaces-quotas-helm-and-troubleshooting/exercises/5-friday-5pm-outage/README.md)**: *Friday, 5 PM. Three things broke. Nobody knows that yet.* Three faults at once, about 30 minutes. Run it after the six sections, when the class has met each kind of fault alone.
- **Two projects** (lab exercises 5 and 6): [Project 1, Canteen Rush](../projects/project-1-canteen-rush/README.md) (deploy, scale, update) and [Project 2, Canteen Rush packaged](../projects/project-2-canteen-helm/README.md) (config, secrets, Jobs, CronJobs, Helm). Students then build their own.

**Every scenario has a `./check.sh`** in its folder. Run it whenever you like: it only looks, never changes anything, and tells you in one line whether you are done.

Each scenario lives in its own namespace, named after its original code (for example `k-08-oomkilled`), so nothing touches your lab work and nothing in your cluster or tests had to change when the folders were reorganised. All images and sizes are in [IMAGES.md](IMAGES.md). A machine-readable list is in [`index.tsv`](index.tsv).

## The short way: one command for everything

You never need to remember a folder path. `z2h.py` (plain Python 3, no packages) finds the scenario for you:

```bash
python3 z2h.py list              # every scenario, by section
python3 z2h.py break S1.2        # set the scene
python3 z2h.py check S1.2        # "am I done?" (read-only)
python3 z2h.py fix S1.2          # apply the fix
python3 z2h.py cleanup S1.2      # remove everything it created
```

It runs the same scripts described below; use whichever you prefer. `break` ends with one line, "the scene is set", and says nothing about the cause: finding it is the exercise.

## How a session runs

1. **Instructor explains**: read the story and the concept in the scenario's `README.md`.
2. **Break it**: `cd break && ./break.sh`
3. **Predict, then investigate by hand.** Every scenario opens its investigation with a **predict-first** box (a few seconds in a 4-minute demo, a full minute in an exercise): say what you expect before you type anything. Then the class types the commands from the README. `break.sh` never explains the cause, that is the class's job. In scenarios with a small `visitor` Pod (most of them; the README says when) open a **second terminal** and run `kubectl logs -f visitor -n <namespace>` (the README gives the exact line) to watch the app fail as a user sees it. (S5.3 has no visitor: watch the autoscaler instead with `kubectl get hpa -n k-25-hpa -w`.)
4. **Meet the tempting wrong fix.** Each scenario names the fix everyone reaches for first (restart it, scale it up, switch the rule off) and shows why it does not work. Then **fix it**: `cd ../fix && ./fix.sh`. If the visitor log is open, the live ❌ → ✅ moment is the best part of the demo.
5. **Verify by hand**: the class checks it really works. `fix.sh` does not verify for you. To open an app, use a **second terminal**:
   ```bash
   kubectl port-forward -n <namespace> svc/<service> 92NN:<port>
   ```
   The scenario README prints the exact line (for example S5.2: `kubectl port-forward -n k-07-slow-start svc/showdown 9207:80`). Then open `http://localhost:92NN` on a laptop. On a playground, add `--address 0.0.0.0` and open the URL for port `92NN`. Press **Ctrl+C** in that terminal to stop it. Several scenarios (for example S5.5, S4.4, S2.3, S2.5 and S2.4) have no web page: you verify them in the terminal.

   **Why the laptop command has no `--address 0.0.0.0`:** without it, `port-forward` listens on `localhost` only. With it, anyone on the same network (venue Wi-Fi) could open your app, and Kanboard's default login is `admin` / `admin`. A playground needs `--address 0.0.0.0` because its URL proxy reaches the app from outside the terminal. Keep `-n <namespace>` right after `port-forward`: `cleanup.sh` finds leftovers by that text.
6. **Clean up**: `cd .. && ./cleanup.sh`

Every `break.sh` cleans up first, so you can run it again and again. Every script works from any folder.

## Platform notes

| Where | What to know |
|-------|--------------|
| kind | Works. The default network add-on of recent kind versions enforces NetworkPolicy, so S3.5 runs. The default StorageClass is `standard`. |
| minikube | Works with a default StorageClass (`standard`). A plain `minikube start` may **not enforce NetworkPolicy**, so S3.5 stops with a clear message: start it with `minikube start --cni=calico` for S3.5. |
| Docker Desktop (Kubernetes enabled) | Works. The StorageClass is called `hostpath`. NetworkPolicy is often **not enforced**, so S3.5 may stop with its message (that is the check working, not a bug). |
| Killercoda, iximiuz | Supported. Open the apps through the platform's "traffic / ports" link for `92NN`. Both should enforce NetworkPolicy (S3.5's `break.sh` checks before it breaks anything). |
| Windows | Use **WSL2** (Ubuntu) and run everything inside it. Git Bash is not enough: the scripts use `pkill` and `pgrep`, which it lacks. |
| Play with Docker | **No Kubernetes there.** Use the Docker scenarios instead, or a Kubernetes playground. |

Things to know before you start:

- **Check your cluster first.** `kubectl config current-context` shows which cluster you are about to break. The scenarios create things in their own `k-NN-...` namespaces, with two exceptions: S2.3 (a taint on the nodes) and S5.3 (metrics-server, only if missing). Their `cleanup.sh` reverts exactly that. Break the right cluster on purpose.
- **S4.3 needs a default StorageClass.** `kubectl get storageclass` must show one marked `(default)`. S4.3's fix is to stop asking for the missing `fast-ssd` class and use that default.
- **S1.1, S1.2 and S4.3 download their app at fix time**, because the Pod never starts while it is broken (S1.1, S1.2: Excalidraw; S4.3: Kanboard). On a cold cluster the fix waits on that download (the first time it can take up to a minute or two): preload it or run the scenario once before class (see the checklist below).
- **S3.5 needs a cluster that enforces NetworkPolicy**, and checks it first (a throwaway `k-13-probe` namespace, deleted straight after). If your cluster ignores policies, it stops with a clear message instead of showing a fake outage.
- **S2.3 changes a node, not just a namespace.** It puts a taint (`z2h-vip`) on one node, so always run its `cleanup.sh` (it removes the taint again; `break.sh` also starts clean). Do not skip it, or the next scenario sees a tainted cluster. On a one-node cluster the taint lands on that node and the watchman is missing everywhere; the lesson is the same.
- **S5.3 installs metrics-server only if your cluster has none**, and removes it again afterwards only if it installed it. Run S5.3 on its own (not alongside other scenarios): adding or removing metrics-server briefly changes the cluster's API list.
- **S6.3 needs Helm** (`helm version` must work). **S3.4 needs a Gateway controller**: install it once with `./scripts/install-gateway.sh` (about 1 GB of memory). Both say so and stop if they are missing.
- **S2.5 takes up to a minute and a half to show its fix**, because a CronJob only fires on the minute. Start the fix, then talk while you wait.
- **S6.x5 is the finale.** Three faults at once, three tracks, about 25 to 30 minutes. Run it after the six sections, when the class has seen each kind of fault on its own.
- **S1.5 leaves a Pod that cannot be deleted** on purpose (a finalizer). Its `cleanup.sh` lifts the finalizer first so the namespace can go; run it, don't just delete the namespace.
- **S6.1 changes your kubeconfig's current namespace** (that is its fix). `./cleanup.sh` puts it back, and only if this scenario was the one that set it. If you are unsure, `kubectl config view --minify -o jsonpath='{..namespace}'` shows where you are looking.
- **S4.x2 to S4.x4 label their namespace with a Pod Security level.** Pod Security Admission is built into Kubernetes 1.25 and later, so it needs nothing installed. S4.x4 also pulls two small nginx images.
- **S6.x2 only reads Pod classes.** It never starves the node, so it is safe on a one-node cluster.
- **S5.x5 needs no metrics-server.** The autoscaler's complaint is about its target, which every cluster can show.
- **S5.x4 sends one eviction request, not a drain.** A real `kubectl drain` would cordon a whole node, which is unsafe on a one-node Docker Desktop or minikube. The robot asks for one Pod only, so it is safe everywhere.
- **Scenarios behave the same on 1 node and 3 nodes** (minikube and Docker Desktop are one node; the course's kind config is three).

Scripts need only `bash`, `kubectl`, `curl` and ordinary Unix tools. No `jq`. Helm is needed for S6.3 only, and the Gateway controller for S3.4 only.

## 🆘 PANIC CARD (when something goes wrong on stage)

Stay calm. Everything lives in the `k-NN-...` namespaces, except S2.3's node taint and S5.3's metrics-server (see above). In this order:

1. **Reset the scenario:** `./cleanup.sh` (from the scenario folder). It is safe at any time, even if nothing is running, and it waits until the namespace is really gone.
2. **Look at what is left:** `kubectl get ns | grep '^k-'`. Anything listed is a scenario namespace; delete one with `kubectl delete ns <name>`.
3. **Port already in use?** An old port-forward is still running: `pkill -f "port-forward -n k-"` (or press Ctrl+C in its terminal).
4. **Run it again:** `./break.sh` again. It starts clean every time.
5. **Pods stuck in Pending in every scenario?** Look for a leftover S2.3 taint: `kubectl describe nodes | grep -A2 Taints`. If you see `z2h-vip`, run `kubernetes/scenarios/2-workloads/3-watchman-skipped-a-gate/cleanup.sh` (or `kubectl taint nodes --all z2h-vip-`).
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

> ⚠️ Use a cluster you can throw away (a fresh playground, a new minikube or kind cluster). The dry run deletes and recreates every `k-NN-…` namespace, and S2.3 (a node taint) and S5.3 (metrics-server) change the cluster (they undo it at the end).

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
5. Run everything except S2.3, S5.3 and S3.4 (it needs the Gateway controller, so give it its own run). The 15 question exercises have no break/fix, so the harness has nothing to run for them. The first group takes the longest, so start it before a coffee:
   ```bash
   ./tests/scenarios/k8s.sh S1.1 S1.2 S1.3 S1.4 S1.5 S1.x1 S1.x2 S1.x3 S2.1 S2.2 S2.4 S2.5 S3.1 S3.2 S3.3 S3.5 S4.1 S4.2 S4.3 S4.4 S4.5 S4.x1 S4.x2 S4.x3 S4.x4 S5.1 S5.2 S5.4 S5.5 S5.x1 S5.x2 S5.x3 S5.x4 S5.x5 S6.1 S6.2 S6.3 S6.4 S6.5 S6.x1 S6.x2 S6.x5
   ```
6. Run S2.3, S5.3 and S3.4 on their own, one after the other (S2.3 taints a node, S5.3 installs metrics-server only if the cluster has none, S3.4 installs the Gateway controller if needed):
   ```bash
   ./tests/scenarios/k8s.sh S2.3
   ```
   ```bash
   ./tests/scenarios/k8s.sh S5.3
   ```
   ```bash
   ./tests/scenarios/k8s.sh S3.4
   ```
7. All ✅ in the summaries means you can tick that platform's column in the table below. Lock the harness again and clean up:
   ```bash
   unset Z2H_DRY_RUN_CONTEXT
   ```
   ```bash
   ./labs.sh k8s clean
   ```

**If you see `Refusing to run`:** step 4 was skipped, or the current context changed since. Repeat steps 3 and 4. The harness only runs when `Z2H_DRY_RUN_CONTEXT` equals the current context exactly.

**If a scenario shows ❌:** run it again on its own (for example `./tests/scenarios/k8s.sh 13`). A second ❌ is real. The lines just above `FAILED at step:` say which check failed. Then run that scenario by hand from its README to see what the room would see. The usual causes are in "Known platform-sensitive scenarios" below (for example, S3.5 needs a cluster that enforces NetworkPolicy).

### Results

Tick each cell after you have run the whole scenario (break, fix, cleanup) on that platform. The build machine tested **kind only** (3 nodes and 1 node, on macOS arm64), so the kind column is ticked; every other cell is still to be ticked by an instructor.

| Scenario | kind | minikube | Docker Desktop | Killercoda | iximiuz | WSL2 |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|
| S1.1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S1.2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S1.3 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S1.4 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S1.5 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S1.x1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S1.x2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S1.x3 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S2.1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S2.2 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S2.3 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S2.4 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S2.5 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S3.1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S3.2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S3.3 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S3.4 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S3.5 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.3 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.4 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.5 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.x1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.x2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.x3 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S4.x4 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.3 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.4 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.5 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.x1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.x2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.x3 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.x4 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S5.x5 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.3 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.4 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.5 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.x1 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.x2 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| S6.x5 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |

**Known platform-sensitive scenarios.** Look at these first:

- **S5.2 and S5.4 timing:** S5.2's app takes about 20 seconds to wake up and S5.4's broken release needs a moment to be refused by its readiness check. On a slow or busy node the restarts and the "timed out" moment come a little later than the README says. Wait for the visible symptom before you start explaining.
- **S5.5 `OOMKilled` vs `Error`:** the kill is the same, but on some clusters and container runtimes the `STATUS` column shows `Error` instead of `OOMKilled`. Check `kubectl describe pod` (the `Last State` shows the reason and exit code 137) before the class.
- **S4.3 StorageClass names:** `standard` on kind and minikube, `hostpath` on Docker Desktop, `local-path` on Killercoda. A default class must exist. S4.3 also downloads Kanboard at fix time (and S1.1, S1.2 download Excalidraw).
- **S3.3 and S3.5 DNS error wording:** the exact message from the failed name lookup (`Name or service not known`, `Temporary failure in name resolution`, ...) differs between images and cluster DNS versions. The idea (the name does not resolve) is the same.
- **S3.5 enforcement:** needs a NetworkPolicy-enforcing cluster. Run it on your platform before class. If it stops with its "not enforced" message, switch cluster (minikube: `--cni=calico`) or skip S3.5.

Found a difference? Write it next to the scenario's README commands, so the next instructor knows.

➡️ Back to the [Kubernetes track](../README.md)
