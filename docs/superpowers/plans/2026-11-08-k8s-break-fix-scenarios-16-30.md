# Kubernetes Break · Investigate · Fix Scenarios 16–30 (batch 3 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `kubernetes/scenarios/16–30`, the new scenarios from the spec lineup: scheduling, quotas, security contexts, config, autoscaling, init containers, mounts, Jobs, sidecars and a three-fault finale. They are built the same way as the shipped K01–K15.

**Architecture:** This batch reuses everything from batch 2 unchanged in spirit: the scenario folder layout, `kubernetes/scenarios/_lib.sh`, the developer harness `tests/scenarios/k8s*.sh` on the throwaway kind cluster `z2h-test`, and the README rules. Two things are new:
- Scenarios that change **cluster-level** state: K16 taints nodes, K25 may install metrics-server. These need helpers that revert exactly what they changed, plus a harness check that nothing cluster-level is left behind.
- A **three-fault finale**, K30.

**Tech Stack:** bash (3.2 safe), kubectl ≥ 1.29, kind for testing, and public multi-arch images ≤ ~60 MB.

**Spec:** `docs/superpowers/specs/2026-11-07-break-fix-scenarios-design.md`. Read §4, §5, §6 (Kubernetes rows 16–30), §8, §10 and §11. Per §11, no Jupyter, VS Code or Uptime Kuma in Kubernetes.

**Read first (the house style and the binding lessons):**
- `docs/superpowers/plans/2026-11-08-k8s-break-fix-scenarios-01-15.md`: its Global Constraints and "Scenario tasks: the common recipe" apply to this batch unchanged, except where this plan says otherwise.
- `kubernetes/scenarios/README.md` (index), `kubernetes/scenarios/03-showdown-crashloop/` (Cats vs Dogs from a ConfigMap), `kubernetes/scenarios/12-showdown-dns-namespaces/` (two components plus a visitor), and `tests/scenarios/k8s/03.sh`.

**Commits:** branch `feat/k8s-scenarios-b`, created from `main` at `e0b8c34`. Implementers commit locally. Nothing goes to `main` or GitHub until the owner says so.

## Global Constraints

Batch 2's Global Constraints apply verbatim (see its plan). Batch 3 adds or changes the following.

**Lessons from batch 2 (binding):**
- README outputs come from one contiguous real run. Never stitch captures together, and never re-stamp them.
- `grep -A/-B` snippets print exactly what is shown.
- The hint comes before any reveal.
- Every investigation step starts with a "why this next" lead-in.
- Show the ❌→✅ moment with `kubectl logs -f visitor` started in a second terminal before `./fix.sh`. Verify snippets show only the post-fix state.
- `fix.sh` and `fixed()` wait for Deployments with `kubectl rollout status … --timeout=180s`. Never use `wait_ready` for the fixed state; `break.sh` never uses `rollout status` to wait for the broken state.
- Test specs `source kubernetes/scenarios/_lib.sh`.
- Timing claims must be true on a cold cluster. Name any image that downloads at fix time, using K10's wording.
- Port-forward commands:
  - Laptop: `kubectl port-forward -n <ns> svc/<name> 92NN:<port>` (localhost only).
  - Playground: the same command plus `--address 0.0.0.0`, written as one sentence.
  - `-n <ns>` always comes directly after `port-forward`.
- Wording must stay true on kind, minikube, Docker Desktop, Killercoda and iximiuz, and on 1-node and 3-node clusters.
- Never name a character "Asha".

**Images (≤ ~60 MB, amd64 and arm64, exact tags):**
- Reuse from `kubernetes/scenarios/IMAGES.md`:
  - `python:3.12-alpine`, `redis:7.4.12-alpine`, `busybox:1.36`, `curlimages/curl:8.11.1`, `nginx:1.27.5-alpine`
  - `kanboard/kanboard:v1.2.57`, `adminer:5.4.1`
  - `excalidraw/excalidraw:latest@sha256:f7ee…` (always with `imagePullPolicy: IfNotPresent`), `corentinth/it-tools:2024.10.22-7ca5933`
- New images, each pinned and added to `IMAGES.md` with "Used by":
  - `nginxinc/nginx-unprivileged:1.27.5-alpine` (~22 MB)
  - `b4bz/homer:<exact tag>` (~7 MB)
  - `traefik/whoami:<exact tag>` (~5 MB; pick a tag that has amd64 and arm64)
  - `registry.k8s.io/metrics-server/metrics-server:v0.8.0` (~22 MB; K25 only)

**Cluster-level changes:**
- Anything outside the scenario namespace must carry the label `z2h.scenario=kNN`, or use a key prefixed `z2h-` (node taints and labels).
- `cleanup.sh` must revert it exactly, and only what this scenario created.
- K16 and K25 are cluster-level. Their tests must run alone, never in parallel with other scenarios.

**Original games and pages only:** any game or page HTML is written for this course. Do not recreate existing commercial games.

## Review Focus

1. **A node taint from K16 survives cleanup** (for example, the presenter presses Ctrl+C mid-break). Every later scenario would then go Pending.
   - `cleanup.sh` must remove `z2h-*` taints from all nodes, idempotently.
   - The harness's leftover check must fail if any node still carries a `z2h-` taint or label.
   - Pinned by `test_untaint_all_is_idempotent` (Task 1) and by K16's double cycle.
2. **metrics-server already existed before K25** (Docker Desktop and some playgrounds ship it). K25's cleanup must never remove a metrics-server it did not install. Pinned by `test_metrics_server_kept_if_preexisting` (Task 1).
3. **Node count differs (1 vs 3, control-plane tainted or not).** K18's replica count must be computed from schedulable nodes. K16 must taint every schedulable node. Pinned by running the full suite on both 1-node and 3-node clusters (Task 17).
4. **Immutable fields** (Job pod template, StatefulSet-like specs). `fix.sh` must delete and recreate, with a comment explaining why. Pinned by the K28 double cycle.
5. **The finale (K30) gets partially fixed by hand on stage, then `fix.sh` runs.** `fix.sh` must be idempotent per fault: apply all three fixes regardless of current state. Pinned by `fixed()` running after a partial manual fix in a third harness cycle (Task 16).

---

## File Structure

```
kubernetes/scenarios/
├── _lib.sh             + untaint_all KEY, schedulable_node_count,
│                         ensure_metrics_server ID, remove_metrics_server_if_ours ID (Task 1)
├── _addons/metrics-server.yaml   pinned v0.8.0 manifest + --kubelet-insecure-tls, labelled (Task 1)
├── 16-game-server-vip-node/ … 30-friday-5pm-outage/   (Tasks 2–15)
├── README.md, IMAGES.md, preload.sh               (updated in Task 16)
tests/scenarios/
├── k8s-lib.sh          nothing_left_k8s also checks node taints/labels with the z2h- prefix (Task 1)
├── k8s-selftest.sh     + new tests (Task 1)
└── k8s/16.sh … 30.sh
```

---

### Task 1: Cluster-level helpers and harness checks

**Files:** Modify `kubernetes/scenarios/_lib.sh`, `tests/scenarios/k8s-lib.sh` and `tests/scenarios/k8s-selftest.sh`. Create `kubernetes/scenarios/_addons/metrics-server.yaml`.

**Interfaces (produced):**
- `schedulable_node_count`: prints the number of nodes with no `NoSchedule`/`NoExecute` taint, using jsonpath. Treat `node-role.kubernetes.io/control-plane:NoSchedule` as unschedulable.
- `untaint_all KEY`: removes the taint `KEY` (all effects) from every node. Silent, idempotent, returns 0. Uses `kubectl taint nodes --all KEY-`, ignoring "not found".
- `ensure_metrics_server ID`:
  - If the `v1beta1.metrics.k8s.io` APIService is Available, print "metrics-server already present" and return 0.
  - Otherwise apply `_addons/metrics-server.yaml`. Every object in it is labelled `z2h.scenario=ID-installed`.
  - Then wait (bounded, 180 s) until `kubectl top nodes` succeeds.
- `remove_metrics_server_if_ours ID`: deletes only objects labelled `z2h.scenario=ID-installed`. Silent, returns 0.
- `tests/scenarios/k8s-lib.sh` `nothing_left_k8s` additionally fails if:
  - any node has a taint whose key starts with `z2h-`, or
  - any node has a label whose key starts with `z2h-`, or
  - any object (cluster-wide, all namespaces) is labelled `z2h.scenario=ID-installed`.

- [ ] **Step 1: Write the self-tests.**
  - `test_untaint_all_is_idempotent`: taint every node `z2h-selftest=yes:NoSchedule`, run `untaint_all z2h-selftest` twice, and assert no node has that key.
  - `test_schedulable_node_count`: assert the result equals the count of nodes without NoSchedule taints, computed independently with a different jsonpath.
  - `test_metrics_server_kept_if_preexisting`:
    - If the test cluster already has metrics-server, skip.
    - Otherwise call `ensure_metrics_server k99`, then apply a second, unlabelled dummy object, then call `remove_metrics_server_if_ours k99`. Assert the APIService is gone and the dummy object stays.
    - Also cover "pre-existing": install it, then relabel it to drop the `-installed` label, then run remove. Assert the APIService remains.
    - Clean up.
  - `test_nothing_left_detects_taint`: taint a node `z2h-x=1:NoSchedule`. Assert `nothing_left_k8s k99 k-99-x` fails. Then untaint.
- [ ] **Step 2: Run the self-test.** `bash tests/scenarios/k8s-selftest.sh` → the new tests fail.
- [ ] **Step 3: Implement.** For the metrics-server manifest, take the official v0.8.0 `components.yaml`. Add `--kubelet-insecure-tls` to the args (kind needs it; say so in a comment) and add the label to every object.
- [ ] **Step 4: Verify.** The self-test is all ✅ on `z2h-test`. shellcheck is clean. The existing `./tests/scenarios/k8s.sh 01 13` is still green (regression check).

---

### Scenario tasks (Tasks 2–16)

Follow batch 2's common recipe exactly. Use namespace `k-NN-<slug>` and port `92NN` where there is a web page. All are 🆕, so there is no `git mv`. Each task lists only its specifics.

### Task 2: K16 `16-game-server-vip-node`, taints and tolerations
- **App:** "Dosa Dash", an original small HTML5 catch game (you may adapt the course's own `docker/scenarios/12-high-score-lost-on-stop` game HTML), served by `nginx:1.27.5-alpine` from a ConfigMap. Service `game` 80. Port 9216. Visitor.
- **Break:** `break.sh` taints **every schedulable node** `z2h-vip=true:NoSchedule` ("ops reserved the nodes for VIP workloads"), then applies the Deployment, which has no toleration. Result: Pending, `untolerated taint {z2h-vip: true}`.
- **Fix:** add a toleration for `z2h-vip=true:NoSchedule` (the README explains the alternative, removing the taint, and why a toleration is the app-side fix).
- **Cleanup:** `untaint_all z2h-vip` plus the namespace.
- **Assert broken:** the Pod is Pending, and the events contain `untolerated taint` (hedge: older versions say `had taint`).
- **Assert fixed:** rollout status passes, and `in_cluster_http … http://game` returns 200.
- **Hook:** "The nodes are up. The game is ready. Kubernetes says: you're not on the list."
- **Concept:** taints repel, tolerations permit; a toleration does not attract (that is K17's topic).
- **Investigate:** `get pods` → `describe pod` (Events) → `kubectl describe nodes | grep -A2 Taints` → `get deploy -o yaml | grep -A4 tolerations` (empty).
- **Lifelong lesson:** "Pending means 'no node would take me'. Ask the nodes what they're refusing."
- **Test:** run alone (cluster-level).

### Task 3: K17 `17-ai-trainer-needs-gpu`, nodeSelector / node affinity
- **App:** the "AI trainer" from K08 (python), with `nodeSelector: {accelerator: nvidia-gpu}`. No node has that label. Namespace `k-17-needs-gpu`. No port.
- **Fix:** replace the nodeSelector with `preferredDuringSchedulingIgnoredDuringExecution` node affinity (the README contrasts required vs preferred, and the option of labelling a node).
- **Assert broken:** Pending, with events containing `didn't match Pod's node affinity/selector`.
- **Assert fixed:** rollout status passes, and the logs contain `model trained`.
- **Hook:** "The trainer is waiting for a GPU that this cluster doesn't have."
- **Lifelong lesson:** "Required rules are promises the cluster must keep. Prefer 'preferred' unless you truly mean 'never run otherwise'."

### Task 4: K18 `18-whoami-anti-affinity`, required pod anti-affinity
- **App:** `traefik/whoami` Deployment `whoami` with required `podAntiAffinity` on `kubernetes.io/hostname`.
- **Break:** replicas = `schedulable_node_count + 1`, computed in `break.sh` and set with `kubectl scale` after apply. The README explains the number.
- **Other details:** Service `whoami` 80, port 9218, visitor printing the answering hostname.
- **Fix:** switch to preferred anti-affinity, which lets all replicas run and spreads them as well as possible.
- **Assert broken:** exactly 1 Pod is Pending, the others are Running, and the events contain `didn't match pod anti-affinity rules`.
- **Assert fixed:** all replicas are Ready.
- **Hook:** "One replica too many. 'Never two on the same node' just met reality."
- **Lifelong lesson:** "Every hard rule needs enough room to be obeyed."
- **Test:** run on both 1-node and 3-node clusters. On 1 node, replicas = 2 (1 Running, 1 Pending).

### Task 5: K19 `19-hackathon-quota`, ResourceQuota
- **App:** a Homer dashboard ("Hackathon team links", config from a ConfigMap) Deployment `dashboard`, 2 replicas, with **no** resources set. Namespace `k-19-hackathon` gets a ResourceQuota `requests.cpu: 500m, requests.memory: 256Mi, limits…`. Port 9219, Service `dashboard` 80 (verify Homer's port).
- **Break:** the quota requires requests/limits, so the ReplicaSet can't create Pods. The Deployment shows `0/2`, and `get pods` shows nothing.
- **Fix:** add requests/limits that fit within the quota.
- **Assert broken:** `kubectl get pods` returns 0 Pods, and the ReplicaSet events contain `forbidden: failed quota` (or `must specify`).
- **Assert fixed:** 2/2 Ready, and `kubectl describe quota` shows used values.
- **Hook:** "The deploy succeeded. Kubernetes created… nothing."
- **Investigate:** `get deploy` (0/2) → `get pods` (none!) → `get rs` → `describe rs` (the reason is here) → `describe quota`.
- **Lifelong lesson:** "When there are no Pods to describe, go one level up."

### Task 6: K20 `20-surprise-limitrange-oom`, LimitRange defaults
- **App:** Cats vs Dogs (python, from the ConfigMap) with **no** resources, Service `showdown`, port 9220, visitor. Namespace `k-20-limitrange` has a LimitRange with default `memory: 32Mi` limit and default request `16Mi`. The app's baseline must exceed 32Mi: verify, and if needed set an env var that preloads data at start, documented honestly.
- **Break:** the Pods get OOMKilled, or crash-loop with OOMKilled; the hook is "nobody wrote a limit".
- **Fix:** set explicit resources (`requests 64Mi`, `limits 128Mi`). The README also mentions fixing the LimitRange and when each is right.
- **Assert broken:** the last terminated reason is OOMKilled or Error with exit 137 (K08 ruling), and `get pod -o jsonpath` shows `limits.memory=32Mi`, which nobody wrote.
- **Assert fixed:** rollout status passes and `/healthz` returns 200.
- **Hook:** "Nobody set a memory limit. The app still got killed for exceeding it."
- **Lifelong lesson:** "Read the spec Kubernetes actually ran, not the one you wrote: `kubectl get pod -o yaml`."

### Task 7: K21 `21-notice-board-runasnonroot`, runAsNonRoot vs a root image
- **App:** "Campus notice board", an original static HTML page from a ConfigMap. The broken version is served by `nginx:1.27.5-alpine` (runs as root) with `securityContext.runAsNonRoot: true` (set by "the security team"). Service `board` 80, port 9221.
- **Fix:** use `nginxinc/nginx-unprivileged:1.27.5-alpine` (uid 101, port 8080, Service targetPort 8080) with the same HTML mount path for that image (verify: `/usr/share/nginx/html`).
- **Assert broken:** `pod_reason` = `CreateContainerConfigError`, and the events contain `runAsNonRoot and image will run as root`.
- **Assert fixed:** rollout status passes and 200.
- **Hook:** "Security turned on one rule. The notice board went dark."
- **Lifelong lesson:** "Fix the image, not the policy. Weakening security is never the fix."

### Task 8: K22 `22-notice-board-readonly-fs`, read-only root filesystem
- **App:** K21's fixed notice board (nginx-unprivileged) plus `readOnlyRootFilesystem: true`. Port 9222.
- **Break:** nginx can't write its temp/cache dirs and goes into CrashLoopBackOff. `logs --previous` shows `mkdir() "/tmp/…" failed (30: Read-only file system)`; verify the exact path.
- **Fix:** `emptyDir` volumes mounted at the writable paths nginx needs (verify which ones: `/tmp`, and maybe `/var/cache/nginx`).
- **Assert broken:** CrashLoopBackOff, and the previous logs contain `Read-only file system`.
- **Assert fixed:** rollout status passes and 200.
- **Hook:** "Locked down perfectly. Now it can't even start."
- **Lifelong lesson:** "Read-only filesystems are great. Give apps a scratchpad for what they must write."

### Task 9: K23 `23-dark-mode-not-applied`, ConfigMap change not picked up
- **App:** a tiny original python stdlib web page "Campus theme" served from a ConfigMap script. It reads env `THEME` (`light`/`dark`) **at startup** and renders a page with matching colours, and `/theme` returns the value. Env comes from ConfigMap `ui-settings` via `envFrom`. Service `theme` 80, port 9223, visitor printing `/theme`.
- **Break:** `break.sh` deploys with `THEME=light`, waits for Ready, then patches the ConfigMap to `dark` ("design team flipped dark mode"). The page stays light.
- **Fix:** `kubectl rollout restart deployment/theme`, then rollout status. The README explains that env vars are read once at start, mounted files update eventually, and the common config-hash annotation pattern.
- **Assert broken:** the ConfigMap says `dark` while `in_cluster_http`… `/theme` body says `light`. Use a body check: add `in_cluster_body` if needed in the spec file itself, not the shared lib.
- **Assert fixed:** `/theme` body = `dark`.
- **Hook:** "Dark mode is ON in the config. The site is still blinding white."
- **Lifelong lesson:** "Changing config is not the same as the app reading it."

### Task 10: K24 `24-showdown-wrong-command`, wrong command
- **App:** Cats vs Dogs with `command: ["pyhton", "/app/app.py"]` (typo). Port 9224.
- **Break:** the container never starts. The status shows `RunContainerError` or `StartError` and then CrashLoopBackOff. The events contain `executable file not found in $PATH`; verify the exact reason names on this version and hedge them.
- **Fix:** `python`.
- **Assert broken:** events or describe contain `executable file not found`, and restarts ≥ 1.
- **Assert fixed:** rollout status passes and 200.
- **Hook:** "No crash log. No error from the app. The app never even ran."
- **Concept:** contrast it with K03, where the app ran and crashed; here the kubelet couldn't exec.
- **Lifelong lesson:** "No logs means it never started. The answer is in the Events."

### Task 11: K25 `25-showdown-hpa-not-scaling`, HPA
- **App:** Cats vs Dogs (python) Deployment `showdown`, 1 replica, **no** CPU requests. HPA `showdown` targets cpu 50%, min 1, max 4. A "load" Pod (busybox) loops `wget http://showdown/api/burn?seconds=2`. Port 9225.
- **Break:** `ensure_metrics_server k25` (Task 1) first. With no requests, `kubectl get hpa` shows `<unknown>/50%` and the events contain `missing request for cpu`.
- **Fix:** add `resources.requests.cpu: 100m` (and a limit), then rollout status. Then wait (bounded, 240 s) until the HPA shows a numeric target and replicas ≥ 2.
- **Cleanup:** the namespace plus `remove_metrics_server_if_ours k25`.
- **Assert broken:** the HPA TARGETS column contains `<unknown>`, and the HPA events contain `missing request for cpu`.
- **Assert fixed:** within 240 s, `status.currentReplicas` ≥ 2 and the TARGETS column is numeric.
- **README:** hedge the timings (HPA sync is about 15 s, metrics lag about 60 s). Say that on clusters that already ship metrics-server, nothing is installed.
- **Hook:** "Traffic is pouring in. The autoscaler shrugs: 'unknown'."
- **Lifelong lesson:** "Autoscaling percentages are percentages of what you requested. No request, no scaling."
- **Test:** run alone (cluster-level addon).

### Task 12: K26 `26-showdown-init-stuck`, init container stuck
- **App:** Redis (Service `redis`) plus Cats vs Dogs with an init container (busybox) `until nslookup redsi; do echo waiting for redsi; sleep 2; done` (typo). Port 9226, visitor.
- **Fix:** the init container waits for `redis`. Also make `REDIS_HOST=redis` consistent.
- **Assert broken:** the Pod status is `Init:0/1`, and `kubectl logs <pod> -c wait-for-redis` contains `waiting for redsi`.
- **Assert fixed:** rollout status passes, `/readyz` returns 200, and votes persist.
- **Hook:** "Cats vs Dogs is waiting for its database. Forever."
- **Concept:** init containers run in order before the app; a stuck init container means the app never starts. Logs need `-c`.
- **Lifelong lesson:** "`Init:0/1` means look at the init container's logs, not the app's."

### Task 13: K27 `27-dashboard-config-missing-key`, volume mount fails
- **App:** Homer dashboard ("Campus quick links") with a ConfigMap volume whose `items` maps key `config.yml` to `/www/assets/config.yml` (verify Homer's config path for the pinned tag). The ConfigMap's key is `config.yaml` (wrong extension). Port 9227.
- **Break:** the Pod is stuck in `ContainerCreating`, and the events contain `FailedMount` with a message about the key not existing; verify the real wording.
- **Fix:** rename the key in the ConfigMap to `config.yml`. Delete and recreate if needed; usually apply suffices.
- **Assert broken:** ContainerCreating for more than 30 s, and the events contain `FailedMount`.
- **Assert fixed:** rollout status passes and 200, and the page contains a link title from the config.
- **Hook:** "The dashboard is ready. Its config is right there. It still won't start."
- **Lifelong lesson:** "`ContainerCreating` that never ends is almost always storage or config. Read the Events."

### Task 14: K28 `28-leaderboard-reset-job`, Job fails
- **App:** Redis (Service `redis`) with demo scores, seeded by `break.sh` with `redis-cli`. Job `leaderboard-reset` (python): connects to `REDIS_HOST` (broken value `leaderbord`, a typo), resets the scores, and prints `✅ leaderboard reset`. `backoffLimit: 2`. Namespace `k-28-job`.
- **Break:** the Job fails 3 times, the condition is `Failed` with reason `BackoffLimitExceeded`, and the Pods show Error.
- **Fix:** delete the Job (its pod template is immutable; comment why) and recreate it with `REDIS_HOST=redis`. Wait for the condition Complete (`kubectl wait --for=condition=complete job/leaderboard-reset --timeout=120s`).
- **Assert broken:** the Job condition is `Failed`, its reason is `BackoffLimitExceeded`, and a Pod log contains a name-resolution error.
- **Assert fixed:** the Job is Complete, the logs contain `leaderboard reset`, and the redis score key is reset.
- **README:** mention CronJob as the scheduled form (no CronJob is created).
- **Hook:** "The midnight reset ran. Three times. Then gave up."
- **Lifelong lesson:** "Jobs retry, then stop. Read the failed Pods: they keep the evidence."

### Task 15: K29 `29-log-sidecar-half-ready`, multi-container 1/2 Ready
- **App:** a Pod in Deployment `notice` with two containers:
  - `web`: nginx-unprivileged serving the notice board and writing its access log to a shared `emptyDir` at `/var/log/web/access.log` (configure nginx accordingly and verify).
  - `log-shipper`: busybox running `tail -F /logs/acess.log` (typo) with a readiness check that the file exists. Use a readiness exec probe so the shipper shows not-ready rather than crashing; decide which is clearer and verify.
- **Other details:** port 9229.
- **Break:** READY `1/2`, and `kubectl logs <pod>` errors with "a container name must be specified". Teach `-c`.
- **Fix:** the correct path, `access.log`.
- **Assert broken:** the Pod's ready count is `1/2`.
- **Assert fixed:** `2/2`, and the `log-shipper` logs show at least one access line after an `in_cluster_http` request.
- **Hook:** "Half ready. Fully confusing."
- **Lifelong lesson:** "In a multi-container Pod, every container tells its own story. Name the one you're asking."

### Task 16: K30 `30-friday-5pm-outage` (finale)
- **App:** Cats vs Dogs plus Redis, with a visitor and port 9230, and **three independent faults** at once. Each fault is found with a different rung of the batch-2 debugging ladder:
  1. Redis image tag typo (`redis:7.4.12-alpnie`), giving ImagePullBackOff.
  2. Service `showdown` targetPort 8000 (the app listens on 8080), giving refused connections.
  3. The app's `REDIS_HOST` is missing, so votes go to per-Pod memory: `/api/info` shows `storage: memory`, and votes don't persist across the 2 replicas.
- **break.sh:** applies all three at once.
- **README format:** "team incident". The room splits into three investigation tracks. Each has a hint, root cause and by-hand fix, applied one at a time with the visitor showing progress (❌ → ⚠️ partial → ✅). The visitor should print the HTTP status and storage type.
- **fix.sh:** applies all three fixes idempotently, whatever is already fixed.
- **Assert broken:** the redis pod_reason is ImagePullBackOff or ErrImagePull, `in_cluster_http http://showdown/healthz` is not 200, and `/api/info` (via Pod IP if needed) shows `memory`.
- **Assert fixed:** 200, storage `redis`, and votes persist across requests.
- **Extra harness check:** in `tests/scenarios/k8s/30.sh`, add a third cycle that applies fix 1 by hand (kubectl set image), then runs `fix.sh`, and asserts fixed. This pins Review Focus #5.
- **Hook:** "Friday, 5 PM. Three things broke. Nobody knows that yet."
- **Lifelong lesson:** "When everything is on fire, fix one thing, verify, then the next. Never three changes at once."

### Task 17: Integration
**Files:**
- Modify: `kubernetes/scenarios/README.md` (lineup 16–30, notes, dry-run rows, remove the "16–30 come later" line), `kubernetes/scenarios/IMAGES.md` and `preload.sh` (new images), `scripts/check-prereqs.sh`, `SHOWTIME.md` and the root `README.md` scenario counts.
- Also K15's "last scenario" Next line becomes a link to K16. K30's Next points to the index.

**Steps:**
- [ ] Link checker (`problems: 0`). `./labs.sh list` shows K01–K30.
- [ ] Cold 3-node: `tests/scenarios/k8s-cluster.sh down && up`, then run `./tests/scenarios/k8s.sh 16 17 18 19 20 21 22 23 24 26 27 28 29 30` → all ✅. Then run `./tests/scenarios/k8s.sh 16` alone and `./tests/scenarios/k8s.sh 25` alone → ✅.
- [ ] Cold 1-node: the same → all ✅ on the first pass.
- [ ] Run `./tests/scenarios/k8s.sh 01 13` once more as a regression check on the shared-lib changes.
- [ ] Self-test all ✅. shellcheck is clean. `preload.sh` against z2h-test: the K16–K30 images load (check one digest-pinned image's Events show "already present").
- [ ] `tests/scenarios/k8s-cluster.sh down`. Report and stop; do not merge.
