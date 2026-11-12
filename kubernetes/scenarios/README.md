# 🔥 Kubernetes break-and-fix scenarios

45 stage demos: 30 main scenarios, four 3-problem practice lanes (K31 to K36, K40 to K45) and three worked examples on topics people meet on the job (K37 to K39). Each one **breaks something in a cluster on purpose**, the class investigates by hand with `kubectl`, then a fix script repairs it. Every scenario has its own folder with a story, the concept, the commands to type, and takeaways.

> **Scenarios vs labs.** Here **K01–K45 means scenario folders** in this directory. They are not the labs K00–K18 in the [Kubernetes track](../README.md).

## The lineup

| # | Scenario | App | Hook | Port | ⬇️ First run |
|---|----------|-----|------|------|------|
| K01 | [The whiteboard that never starts](01-excalidraw-pending/README.md) | Excalidraw whiteboard | *We asked for a whiteboard. Kubernetes heard "a data centre".* | `9201` | 48 MB |
| K02 | [The one-letter typo](02-image-typo/README.md) | Excalidraw whiteboard | *One missing letter. Kubernetes tries, waits, tries again… forever.* | `9202` | 48 MB |
| K03 | [The loop](03-showdown-crashloop/README.md) | Cats vs Dogs voting app | *It starts. It dies. It starts. It dies. Welcome to the loop.* | `9203` | 23 MB |
| K04 | [Running is not reachable](04-it-tools-no-endpoints/README.md) | IT-Tools | *Every Pod is Running. Every request fails.* | `9204` | 28 MB |
| K05 | [Right Pod, wrong door](05-excalidraw-wrong-port/README.md) | Excalidraw whiteboard | *Endpoints exist. The Pod is fine. Still: connection refused.* | `9205` | 48 MB |
| K06 | [Running, healthy, and never any visitors](06-kanboard-never-ready/README.md) | Kanboard | *It's running. It's healthy. It just never gets any visitors.* | `9206` | 37 MB |
| K07 | [The impatient guard](07-showdown-slow-start/README.md) | Cats vs Dogs voting app | *A perfectly healthy app keeps getting killed, again and again, every few seconds.* | `9207` | 23 MB |
| K08 | [No error, no goodbye (Kubernetes edition)](08-ai-trainer-oomkilled/README.md) | an "AI trainer" script (terminal only) | *Your AI model was training. Then it vanished. No error. No goodbye. And Kubernetes keeps bringing it back to die again.* | - | 19 MB |
| K09 | [The container that never got created](09-adminer-missing-secret/README.md) | Adminer | *The database tool won't even start. No logs. Nothing.* | `9209` | 50 MB |
| K10 | [The task board is waiting for a disk that will never arrive](10-kanboard-pvc-pending/README.md) | Kanboard | *The Pod isn't crashing. It isn't even starting. It's waiting for a disk that doesn't exist.* | `9210` | 37 MB |
| K11 | [The Friday release](11-showdown-bad-rollout/README.md) | Cats vs Dogs voting app | *Friday, 6 PM. The release goes out. Nobody notices… because Kubernetes saved you.* | `9211` | 23 MB |
| K12 | [Same cluster, same name, "never heard of it"](12-showdown-dns-namespaces/README.md) | Cats vs Dogs + Redis | *The Redis is running. The app is running. And the app swears Redis does not exist.* | `9212` | 82 MB |
| K13 | [Security hardened the network. Now nothing can find anything.](13-lockdown-blocks-dns/README.md) | Cats vs Dogs + Redis | *Security locked the app down so it can only talk to Redis. And now the app cannot even find Redis.* | `9213` | 82 MB |
| K14 | [The bot has an ID card, but the door stays shut](14-leaderboard-bot-forbidden/README.md) | a "leaderboard bot" (terminal only) | *The bot has a valid ID card. The API still says: not allowed.* | - | 16 MB |
| K15 | [The mystery variable](15-mystery-redis-port/README.md) | a Python score worker + Redis (terminal only) | *Nobody set `REDIS_PORT`. Kubernetes did.* | - | 82 MB |
| K16 | [You're not on the list](16-game-server-vip-node/README.md) | Dosa Dash game | *The nodes are up. The game is ready. Kubernetes says: you're not on the list.* | `9216` | 25 MB |
| K17 | [The trainer wants a GPU](17-ai-trainer-needs-gpu/README.md) | an "AI trainer" script (terminal only) | *The trainer is waiting for a GPU that this cluster doesn't have.* | - | 19 MB |
| K18 | [One replica too many](18-whoami-anti-affinity/README.md) | whoami (tells you which Pod answered) | *One replica too many. "Never two on the same node" just met reality.* | `9218` | 10 MB |
| K19 | [The deploy that created nothing](19-hackathon-quota/README.md) | Homer dashboard ("Hackathon team links") | *The deploy succeeded. Kubernetes created… nothing.* | `9219` | 11 MB |
| K20 | [The limit nobody wrote](20-surprise-limitrange-oom/README.md) | Cats vs Dogs voting app | *"Nobody set a memory limit. The app still got killed for exceeding it."* | `9220` | 23 MB |
| K21 | [The rule that turned the lights off](21-notice-board-runasnonroot/README.md) | Campus notice board | *Security turned on one rule. The notice board went dark.* | `9221` | 47 MB |
| K22 | [Locked down and locked out](22-notice-board-readonly-fs/README.md) | Exam Week Board | *Locked down perfectly. Now it can't even start.* | `9222` | 26 MB |
| K23 | [Dark mode is on. The site is still white.](23-dark-mode-not-applied/README.md) | "Campus Today" notice page | *Dark mode is ON in the config. The site is still blinding white.* | `9223` | 23 MB |
| K24 | [The app that never ran](24-showdown-wrong-command/README.md) | Cats vs Dogs voting app | *No crash log. No error from the app. The app never even ran.* | `9224` | 23 MB |
| K25 | [The autoscaler that shrugs](25-showdown-hpa-not-scaling/README.md) | Cats vs Dogs voting app + metrics-server | *Traffic is pouring in. The autoscaler shrugs: "unknown".* | `9225` | 45 MB |
| K26 | [Stuck before it starts](26-showdown-init-stuck/README.md) | Cats vs Dogs + Redis | *Cats vs Dogs is waiting for its database. Forever.* | `9226` | 82 MB |
| K27 | [The dashboard that never starts](27-dashboard-config-missing-key/README.md) | Homer dashboard ("Campus quick links") | *The dashboard is ready. Its config is right there. It still won't start.* | `9227` | 11 MB |
| K28 | [The nightly reset that gave up](28-leaderboard-reset-job/README.md) | a reset Job + Redis (terminal only) | *The midnight reset ran. Three times. Then gave up.* | - | 78 MB |
| K29 | [Half ready](29-log-sidecar-half-ready/README.md) | Hostel Notice Board | *Half ready. Fully confusing.* | `9229` | 26 MB |
| K30 | [The Friday 5 PM outage (the finale)](30-friday-5pm-outage/README.md) | Cats vs Dogs + Redis | *Friday, 5 PM. Three things broke. Nobody knows that yet.* | `9230` | 82 MB |
| K31 | [Two stalls, one signboard](31-two-stalls-one-signboard/README.md) | Chai stall (practice) | *Some customers get hot chai. Some get… yesterday's.* | `9231` | 17 MB |
| K32 | [The label on the wrong object](32-label-on-the-wrong-object/README.md) | Samosa stall (practice) | *The label is right there. Kubernetes is looking somewhere else.* | `9232` | 17 MB |
| K33 | [Two bugs in one trench coat](33-canteen-two-bugs/README.md) | Canteen counter (boss) | *You fixed it. It is still broken. Welcome to the boss level.* | `9233` | 17 MB |
| K34 | [The doorbell on the wrong door](34-doorbell-on-the-wrong-door/README.md) | Dosa counter (practice) | *The counter is open and the cook is ready. The doorbell is wired to the house next door.* | `9234` | 17 MB |
| K35 | [The biryani that needs 20 seconds](35-biryani-that-needs-20-seconds/README.md) | Biryani counter (practice) | *Good things come to those who wait. Kubernetes did not get the memo.* | `9235` | 4 MB |
| K36 | [Two probes, two mistakes](36-two-probes-two-mistakes/README.md) | Thali counter (boss) | *Two managers who disagree about everything. One closed stall.* | `9236` | 4 MB |
| K37 | [The Pod that will not leave](37-pod-that-will-not-leave/README.md) | an old stall (terminal only) | *You said delete. Kubernetes said yes. The Pod did not get the message.* | - | 17 MB |
| K38 | [Applied here, looking there](38-applied-here-looking-there/README.md) | Night canteen | *The deploy said "created". The cluster says "No resources found". Both are telling the truth.* | `9238` | 21 MB |
| K39 | [The robot that cannot move the stalls](39-robot-that-cannot-move-the-stalls/README.md) | Idli stall | *Every night the maintenance robot asks to move one Pod. Every night the answer is no.* | `9239` | 21 MB |
| K40 | [The stall that asked for too much](40-stall-that-asked-for-too-much/README.md) | Chaat stall (practice) | *The Pod asked for a gigabyte. The kitchen rule said: 128 megabytes, no more.* | `9240` | 17 MB |
| K41 | [The autoscaler pointing at nobody](41-autoscaler-pointing-at-nobody/README.md) | Lassi stall (practice) | *The lassi stall is fine. The autoscaler is watching a stall that does not exist.* | `9241` | 17 MB |
| K42 | [Who gets evicted first](42-who-gets-evicted-first/README.md) | Three little stalls (boss, terminal only) | *When the node runs out of memory, Kubernetes has a list. You decide where each Pod stands on it.* | - | 17 MB |
| K43 | [The maintenance van wants the master key](43-maintenance-van-wants-the-master-key/README.md) | Chai van (practice) | *The van only wanted to serve chai. It asked for a key to the entire market.* | `9243` | 17 MB |
| K44 | [The checklist](44-the-checklist/README.md) | Kitchen cart (practice) | *The gate does not say "no". It hands you a checklist, and your kitchen cart ticks none of it.* | `9244` | 17 MB |
| K45 | [The locked-down kitchen](45-the-locked-down-kitchen/README.md) | Kitchen (boss) | *The paperwork is perfect. The cook still cannot start. Welcome to the boss level.* | `9245` | 42 MB |

### 🏋️ Practice lanes
Reading about a fix is not the same as finding one alone. A **practice lane** takes one idea from a scenario you have already done (the *worked example*) and gives you more problems on the same idea, each with less help than the last. K31 to K33 are the first lane: **"Services find Pods"**, after [K04](04-it-tools-no-endpoints/README.md).

| Step | Scenario | You get |
|---|---|---|
| Worked example | [K04](04-it-tools-no-endpoints/README.md) | every step explained |
| Guided | [K31](31-two-stalls-one-signboard/README.md) | questions and a hint ladder |
| Mostly solo | [K32](32-label-on-the-wrong-object/README.md) | questions only |
| Boss | [K33](33-canteen-two-bugs/README.md) | no hints for the first 5 minutes |

A second lane, **"Ready or alive?"**, follows the same pattern after [K06](06-kanboard-never-ready/README.md) and [K07](07-showdown-slow-start/README.md):

| Step | Scenario | You get |
|---|---|---|
| Worked examples | [K06](06-kanboard-never-ready/README.md), [K07](07-showdown-slow-start/README.md) | every step explained |
| Guided | [K34](34-doorbell-on-the-wrong-door/README.md) | questions and a hint ladder |
| Mostly solo | [K35](35-biryani-that-needs-20-seconds/README.md) | questions only |
| Boss | [K36](36-two-probes-two-mistakes/README.md) | no hints for the first 5 minutes |

Two more lanes cover resources and security. **"Resources"**, after [K08](08-ai-trainer-oomkilled/README.md), [K20](20-surprise-limitrange-oom/README.md) and [K25](25-showdown-hpa-not-scaling/README.md):

| Step | Scenario | You get |
|---|---|---|
| Worked examples | [K08](08-ai-trainer-oomkilled/README.md), [K20](20-surprise-limitrange-oom/README.md), [K25](25-showdown-hpa-not-scaling/README.md) | every step explained |
| Guided | [K40](40-stall-that-asked-for-too-much/README.md) | questions and a hint ladder |
| Mostly solo | [K41](41-autoscaler-pointing-at-nobody/README.md) | questions only |
| Boss | [K42](42-who-gets-evicted-first/README.md) | no hints for the first 5 minutes |

**"Security"**, after [K21](21-notice-board-runasnonroot/README.md) and [K22](22-notice-board-readonly-fs/README.md):

| Step | Scenario | You get |
|---|---|---|
| Worked examples | [K21](21-notice-board-runasnonroot/README.md), [K22](22-notice-board-readonly-fs/README.md) | every step explained |
| Guided | [K43](43-maintenance-van-wants-the-master-key/README.md) | questions and a hint ladder |
| Mostly solo | [K44](44-the-checklist/README.md) | questions only |
| Boss | [K45](45-the-locked-down-kitchen/README.md) | no hints for the first 5 minutes |

Every practice scenario has a `./check.sh` in its folder. Run it whenever you like: it only looks, never changes anything, and tells you whether you are done.

Scenario `NN` uses local port `92NN` (the apps you can open in a browser). Each scenario lives in its own namespace named `k-NN-<slug>` (K12 uses two, K13 also creates a short-lived `k-13-probe`), so nothing touches your lab work. Logins: Kanboard (K06, K10) uses the default `admin` / `admin`; the other apps need no login (Adminer in K09 only shows its login form, and there is no database behind it). All images and sizes are in [IMAGES.md](IMAGES.md).

## How a session runs

1. **Instructor explains**: read the story and the concept in the scenario's `README.md`.
2. **Break it**: `cd break && ./break.sh`
3. **Predict, then investigate by hand.** Every scenario (K01 to K29, and the practice lanes) opens its investigation with a 60-second **predict-first** box: say what you expect before you type anything. Then the class types the commands from the README. `break.sh` never explains the cause, that is the class's job. In scenarios with a small `visitor` Pod (K01–K07, K09–K13, K16, K18–K24, K26, K27, K29, K30) open a **second terminal** and run `kubectl logs -f visitor -n <namespace>` (the README gives the exact line) to watch the app fail as a user sees it. (K25 has no visitor: watch the autoscaler instead with `kubectl get hpa -n k-25-hpa -w`.)
4. **Meet the tempting wrong fix.** Each scenario names the fix everyone reaches for first (restart it, scale it up, switch the rule off) and shows why it does not work. Then **fix it**: `cd ../fix && ./fix.sh`. If the visitor log is open, the live ❌ → ✅ moment is the best part of the demo.
5. **Verify by hand**: the class checks it really works. `fix.sh` does not verify for you. To open an app, use a **second terminal**:
   ```bash
   kubectl port-forward -n <namespace> svc/<service> 92NN:<port>
   ```
   The scenario README prints the exact line (for example K07: `kubectl port-forward -n k-07-slow-start svc/showdown 9207:80`). Then open `http://localhost:92NN` on a laptop. On a playground, add `--address 0.0.0.0` and open the URL for port `92NN`. Press **Ctrl+C** in that terminal to stop it. K08, K14, K15, K17 and K28 have no web page: you verify them in the terminal.

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
- **K16 changes every node, not just a namespace.** It puts a taint (`z2h-vip`) on the nodes, so always run its `cleanup.sh` (it removes the taint again; `break.sh` also starts clean). Do not skip it, or the next scenario sees a tainted cluster.
- **K25 installs metrics-server only if your cluster has none**, and removes it again afterwards only if it installed it. Run K25 on its own (not alongside other scenarios): adding or removing metrics-server briefly changes the cluster's API list.
- **K30 is the finale.** Three faults at once, three tracks, about 25 to 30 minutes. Run it after the others, when the class has seen each kind of fault on its own.
- **K37 leaves a Pod that cannot be deleted** on purpose (a finalizer). Its `cleanup.sh` lifts the finalizer first so the namespace can go; run it, don't just delete the namespace.
- **K38 changes your kubeconfig's current namespace** (that is its fix). `./cleanup.sh` puts it back, and only if this scenario was the one that set it. If you are unsure, `kubectl config view --minify -o jsonpath='{..namespace}'` shows where you are looking.
- **K43 to K45 label their namespace with a Pod Security level.** Pod Security Admission is built into Kubernetes 1.25 and later, so it needs nothing installed. K45 also pulls two small nginx images.
- **K42 only reads Pod classes.** It never starves the node, so it is safe on a one-node cluster.
- **K41 needs no metrics-server.** The autoscaler's complaint is about its target, which every cluster can show.
- **K39 sends one eviction request, not a drain.** A real `kubectl drain` would cordon a whole node, which is unsafe on a one-node Docker Desktop or minikube. The robot asks for one Pod only, so it is safe everywhere.
- **Scenarios behave the same on 1 node and 3 nodes** (minikube and Docker Desktop are one node; the course's kind config is three).

Scripts need only `bash`, `kubectl`, `curl` and ordinary Unix tools. No `jq`, no `helm`.

## 🆘 PANIC CARD (when something goes wrong on stage)

Stay calm. Everything lives in the `k-NN-...` namespaces, except K16's node taint and K25's metrics-server (see above). In this order:

1. **Reset the scenario:** `./cleanup.sh` (from the scenario folder). It is safe at any time, even if nothing is running, and it waits until the namespace is really gone.
2. **Look at what is left:** `kubectl get ns | grep '^k-'`. Anything listed is a scenario namespace; delete one with `kubectl delete ns <name>`.
3. **Port already in use?** An old port-forward is still running: `pkill -f "port-forward -n k-"` (or press Ctrl+C in its terminal).
4. **Run it again:** `./break.sh` again. It starts clean every time.
5. **Pods stuck in Pending in every scenario?** Look for a leftover K16 taint: `kubectl describe nodes | grep -A2 Taints`. If you see `z2h-vip`, run `kubernetes/scenarios/16-game-server-vip-node/cleanup.sh` (or `kubectl taint nodes --all z2h-vip-`).
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

> ⚠️ Use a cluster you can throw away (a fresh playground, a new minikube or kind cluster). The dry run deletes and recreates every `k-NN-…` namespace, and K16 and K25 change the whole cluster (they undo it at the end).

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
5. Run everything except K16 and K25:
   ```bash
   ./tests/scenarios/k8s.sh 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 17 18 19 20 21 22 23 24 26 27 28 29 30
   ```
6. Run K16 and K25 on their own, one after the other (they change every node, and install metrics-server only if the cluster has none):
   ```bash
   ./tests/scenarios/k8s.sh 16
   ```
   ```bash
   ./tests/scenarios/k8s.sh 25
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
| K15 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K16 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K17 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K18 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K19 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K20 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K21 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K22 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K23 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K24 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K25 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K26 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K27 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K28 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K29 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K30 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K31 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K32 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K33 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K34 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K35 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K36 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K37 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K38 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K39 | ✅ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K40 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K41 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K42 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K43 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K44 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K45 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

**Known platform-sensitive scenarios.** Look at these first:

- **K07 and K11 timing:** K07's app takes about 20 seconds to wake up and K11's broken release needs a moment to be refused by its readiness check. On a slow or busy node the restarts and the "timed out" moment come a little later than the README says. Wait for the visible symptom before you start explaining.
- **K08 `OOMKilled` vs `Error`:** the kill is the same, but on some clusters and container runtimes the `STATUS` column shows `Error` instead of `OOMKilled`. Check `kubectl describe pod` (the `Last State` shows the reason and exit code 137) before the class.
- **K10 StorageClass names:** `standard` on kind and minikube, `hostpath` on Docker Desktop, `local-path` on Killercoda. A default class must exist. K10 also downloads Kanboard at fix time (and K01, K02 download Excalidraw).
- **K12 and K13 DNS error wording:** the exact message from the failed name lookup (`Name or service not known`, `Temporary failure in name resolution`, ...) differs between images and cluster DNS versions. The idea (the name does not resolve) is the same.
- **K13 enforcement:** needs a NetworkPolicy-enforcing cluster. Run it on your platform before class. If it stops with its "not enforced" message, switch cluster (minikube: `--cni=calico`) or skip K13.

Found a difference? Write it next to the scenario's README commands, so the next instructor knows.

➡️ Back to the [Kubernetes track](../README.md)
