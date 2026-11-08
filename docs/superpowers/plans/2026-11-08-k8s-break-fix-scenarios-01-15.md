# Kubernetes Break · Investigate · Fix Scenarios 01–15 (batch 2 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `kubernetes/troubleshooting/` (15 scenarios run through `labs.sh`) with `kubernetes/scenarios/01–15`: stage-ready break/fix scenarios built on light, recognisable apps. Each has `README.md`, `cleanup.sh`, `break/` and `fix/`, the same model as the shipped Docker track.

**Architecture:** One folder per scenario, with one namespace per scenario (`k-NN-slug`). `kubernetes/scenarios/_lib.sh` reuses the generic helpers of `docker/scenarios/_lib.sh` (it sources it) and adds the cluster helpers. A developer-only harness (`tests/scenarios/k8s.sh`) runs each scenario twice on a **dedicated throwaway kind cluster** and never touches other clusters. Apps open with a hand-typed `kubectl port-forward`.

**Tech Stack:** bash, kubectl ≥ 1.29, kind (testing), public multi-arch images ≤ ~60 MB. Cats vs Dogs runs from `python:3.12-alpine` with its code in a ConfigMap; no custom images.

**Spec:** `docs/superpowers/specs/2026-11-07-break-fix-scenarios-design.md`. Read §3, §4, §5, §6 (Kubernetes table), §8, §10 and §11, especially §10.2 (NetworkPolicy guard), §10.4 (no local images in K8s), §10.7 (port-forward by hand) and §11 (≤ 60 MB images).

**Reuse from batch 1:** `docker/scenarios/_lib.sh` (generic helpers), `tests/scenarios/lib.sh` (asserts), and the README conventions in `docker/scenarios/*/README.md`. Before writing, read one finished Docker scenario, e.g. `docker/scenarios/03-votes-cant-reach-redis/`, as the house style.

**Batch boundaries:**
- This batch covers Kubernetes 01–15.
- 16–30 get their own plan.
- `kubernetes/troubleshooting/` is migrated away completely here, since all 15 are ♻️.

**Commits:** work on branch `feat/k8s-scenarios-a` in the worktree. Implementers commit locally. Nothing reaches `main`/GitHub until the owner says "Merge & push" / "Commit & push".

## Global Constraints

- **Scripts:**
  - `bash`, shebang `#!/usr/bin/env bash`, `set -u` (no `set -e` in `cleanup.sh`), mode 755, `shellcheck -S warning` clean.
  - bash 3.2 safe (macOS `/bin/bash`): no associative arrays, `mapfile`, `${var,,}`.
- **Allowed tools in scripts:**
  - Allowed: `kubectl`, `docker` (only in preload/test tooling), `kind` (only in test tooling and in `preload.sh` when detected), `curl`, `grep`, `sed`, `awk`, `sleep`, `printf`, `cat`, `pkill`.
  - Not allowed: `jq`, `envsubst`, `timeout`, `helm`, `yq`, GNU-only flags.
- **Naming:**
  - Scenario NN uses namespace `k-NN-<slug>` (e.g. `k-07-slow-start`). K12 uses two: `k-12-<slug>-app` and `k-12-<slug>-data`.
  - Everything the scenario creates lives in its namespace(s). Cluster-scoped objects (none expected in 01–15) would carry the label `z2h.scenario=kNN`.
- **Access:**
  - Apps are opened by hand with `kubectl port-forward -n <ns> --address 0.0.0.0 svc/<name> 92NN:<port>` (K07 → 9207), in a second terminal.
  - Write `-n <ns>` directly after `port-forward`, so `cleanup.sh` can stop leftovers with `pkill -f "port-forward -n <ns>"`.
  - README "open it" lines: laptop `http://localhost:92NN`; playground: the URL for port 92NN.
- **Logins:** password `change-me-123` where an app needs one.
- **Images:**
  - linux/amd64 + linux/arm64, ≤ ~60 MB, pinned to an exact tag. Record them in `kubernetes/scenarios/IMAGES.md`.
  - Allowed set (spec §11):
    - `excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9`
    - `corentinth/it-tools:2024.10.22-7ca5933`
    - `kanboard/kanboard`, `adminer`, `b4bz/homer`, `traefik/whoami` (pin exact tags)
    - `nginx:1.27.5-alpine`, `nginxinc/nginx-unprivileged` (pin)
    - `python:3.12-alpine`, `redis:7.4.12-alpine`, `busybox:1.36`, `curlimages/curl:8.11.1`
  - Reuse batch 1's pins where they exist.
- **Cats vs Dogs** runs as `python:3.12-alpine` with `command: ["python", "/app/app.py"]`. Its code comes from ConfigMap `showdown-code` (keys `app.py`, `index.html`), mounted at `/app` with items `app.py → app.py` and `index.html → static/index.html`. The ConfigMap is created by `create_showdown_configmap` (Task 1) from `apps/api/`, so it is never copied into scenario folders.
- **Clusters:** each scenario behaves the same on 1 node (minikube, Docker Desktop) and 3 nodes (kind, repo config). Assume a default StorageClass. NetworkPolicy enforcement is assumed only where K13's guard checks it.
- **Line endings:** LF via `.gitattributes` (already present).
- **Content:**
  - The README follows spec §5's 13-part order.
  - All README lessons from batch 1 apply:
    - Every investigation step shows real output, captured from a real run (never invented).
    - "What changed" is shown with a focused command and its real output.
    - The hint comes before the steps that reveal the answer.
    - Verify reproduces its output when run in order after `fix.sh`.
    - A "by hand" block says that it replaces `fix.sh`.
    - Shortened output is marked "(shortened)".
  - Character names: never "Asha" (use Lakshmi, Ravi, Meera, Priya, Arjun).
- **Behaviour:** `break.sh` never diagnoses; `fix.sh` never verifies. Both end by printing what to type next.

## Review Focus

1. **The harness or a script runs against the wrong cluster** (for example the owner's other kind clusters). The test tooling must refuse unless the current context is the throwaway test cluster. This is pinned by `test_refuses_foreign_context` (Task 1).
2. **A namespace is still Terminating when `break.sh` re-runs straight after `cleanup.sh`.** `cleanup.sh` must wait until the namespace is gone (bounded), so an immediate re-run works. This is pinned by `test_cleanup_waits_for_namespace` (Task 1) and by the harness's double cycle.
3. **A leftover `kubectl port-forward` holds port 92NN.** `cleanup.sh` stops it, and `break.sh` reports a busy port by name. This is pinned by `test_cleanup_stops_port_forward` (Task 1).
4. **No cluster is reachable, or kubectl is missing.** A friendly one-liner prints, and the script exits 1. This is pinned by `test_no_cluster_message` (Task 1).
5. **First-time image pulls on slow Wi-Fi make a Pod sit in `ContainerCreating`.**
   - `break.sh` waits for the intended failure, bounded at 180 s for pulls.
   - The README says a slow first download is normal.
   - Covered by every scenario's harness run on a cold cluster: the harness deletes and recreates the test cluster before the first full run (Task 17).

---

## File Structure

```
kubernetes/scenarios/
├── README.md     index: lineup, session flow, port-forward how-to, platform notes
│                 (Killercoda/iximiuz/kind/minikube/Docker Desktop; Play with Docker = no K8s),
│                 panic card, instructor preload checklist, dry-run checklist
├── IMAGES.md     pinned images + sizes + used-by
├── _lib.sh       sources ../../docker/scenarios/_lib.sh for say/ok/warn/die/wait_for/show_next,
│                 adds cluster helpers (Task 1)
├── preload.sh    pulls IMAGES.md images; loads them into kind/minikube when detected
└── NN-slug/      README.md · cleanup.sh · break/{break.sh, *.yaml} · fix/{fix.sh, *.yaml}
tests/scenarios/
├── k8s-cluster.sh    up|down: throwaway kind cluster "z2h-test" (3 nodes, no host port mappings),
│                     kubeconfig at $HOME/.kube/z2h-test.config
├── k8s-lib.sh        k8s harness helpers + run_cycle_k8s
├── k8s.sh            ./tests/scenarios/k8s.sh [NN ...]
├── k8s-selftest.sh   Review Focus tests for kubernetes/scenarios/_lib.sh
└── k8s/NN.sh         broken() and fixed() for scenario NN (mode 644)
```
Removed at the end: `kubernetes/troubleshooting/`. Each ♻️ scenario is `git mv`'d from it, then reshaped.

---

### Task 1: Kubernetes shared library, test cluster and harness

**Files:**
- Create: `kubernetes/scenarios/_lib.sh`, `tests/scenarios/k8s-cluster.sh`, `tests/scenarios/k8s-lib.sh`, `tests/scenarios/k8s.sh`, `tests/scenarios/k8s-selftest.sh`

**Interfaces:**
- Consumes: from `docker/scenarios/_lib.sh`: `say`, `ok`, `warn`, `die`, `wait_for DESC SECONDS CMD...`, `show_next MSG...`. Its `need_docker` and `scenario_cleanup` are not used. Sourcing it must have no side effects other than defining functions and exporting `MSYS_NO_PATHCONV`. Verify this, and report if not.
- Produces, in `kubernetes/scenarios/_lib.sh`. It is sourced like the Docker one: `break/` and `fix/` use `$(cd "$(dirname "$0")/../.." && pwd)/_lib.sh`, and `cleanup.sh` uses `$(cd "$(dirname "$0")/.." && pwd)/_lib.sh`.
  - `need_cluster`:
    - If `kubectl` is missing: `die "kubectl isn't installed. See 00-setup."`
    - If `kubectl get --raw /readyz` fails: `die "Can't reach a Kubernetes cluster. Check: kubectl config current-context"`
  - `fresh_ns NS...`:
    - Calls `delete_ns` for each NS, then `kubectl create namespace NS`.
    - Labels each NS `z2h.scenario=<kNN>`, derived from the `k-NN-` prefix.
  - `delete_ns NS...`:
    - Runs `kubectl delete namespace NS --ignore-not-found --wait=false`.
    - Then polls up to 120 s until `kubectl get namespace NS` fails.
    - Silent, and always returns 0.
  - `stop_port_forwards NS...`: `pkill -f "port-forward -n NS"`, silent, returns 0.
  - `port_free PORT`: same contract as the Docker `port_free`, but it names a `kubectl port-forward` holder if one exists.
  - `create_showdown_configmap NS`:
    - Creates ConfigMap `showdown-code` in NS from `apps/api/app.py` and `apps/api/static/index.html`, with keys `app.py` and `index.html`.
    - Locates `apps/api/` relative to `_lib.sh`.
  - `pod_reason NS SELECTOR`: prints the first Pod's container `state.waiting.reason`, or else `lastState.terminated.reason`, or else `phase` (via `-o jsonpath`).
  - `scenario_k8s_cleanup NS...`:
    - Runs `stop_port_forwards`, then `delete_ns`.
    - Prints `✅ Scenario <kNN> cleaned up`.
    - Never fails.
- Produces, in `tests/scenarios/k8s-cluster.sh`:
  - `up`: creates kind cluster `z2h-test` (1 control-plane + 2 workers, no `extraPortMappings`) with `--kubeconfig $HOME/.kube/z2h-test.config`, and prints the `export KUBECONFIG=…` line.
  - `up --single`: creates the same cluster with 1 node.
  - `down`: deletes it.
  - `status`.
- Produces, in `tests/scenarios/k8s-lib.sh`:
  - Sources `tests/scenarios/lib.sh` for the asserts.
  - `require_test_cluster`: fails unless `kubectl config current-context` = `kind-z2h-test`.
  - `in_cluster_http NS URL`:
    - Runs a throwaway `curlimages/curl:8.11.1` pod in NS (`kubectl run --rm -i --restart=Never`).
    - Prints the HTTP code, or `000`.
  - `wait_ready NS SELECTOR SECONDS`.
  - `run_cycle_k8s DIR ID NS...`:
    - The same two-cycle flow as `run_cycle`.
    - Its "nothing left" check: no namespace NS exists, no `port-forward -n NS` process, and no cluster-scoped object labelled `z2h.scenario=ID` (clusterroles, clusterrolebindings, PVs).
- Produces, in `tests/scenarios/k8s.sh`:
  - Usage: `./tests/scenarios/k8s.sh [NN ...]`.
  - Calls `require_test_cluster` first.
  - Sources `tests/scenarios/k8s/NN.sh`, which defines `broken()`, `fixed()` and `NAMESPACES="…"`.
  - Prints a ✅/❌ summary.

- [ ] **Step 1: Write `tests/scenarios/k8s-selftest.sh`**:
  - `test_no_cluster_message`: `KUBECONFIG=/nonexistent bash -c 'source kubernetes/scenarios/_lib.sh; need_cluster'` exits 1, and its output contains `Can't reach a Kubernetes cluster`.
  - `test_refuses_foreign_context`: with `KUBECONFIG` pointing at a temp kubeconfig whose current-context is `not-the-test-cluster`, `bash tests/scenarios/k8s.sh 01` exits non-zero, and its output contains `kind-z2h-test`.
  - `test_cleanup_waits_for_namespace`: `fresh_ns k-99-selftest`, create a busybox Pod in it, then `delete_ns k-99-selftest`. Assert that `kubectl get ns k-99-selftest` fails immediately afterwards, then `fresh_ns k-99-selftest` succeeds at once. Clean up.
  - `test_cleanup_stops_port_forward`: create a Deployment and Service (`traefik/whoami`) in `k-98-selftest`, start `kubectl port-forward -n k-98-selftest --address 127.0.0.1 svc/whoami 9298:80 &`, and wait until `curl -s localhost:9298` answers. Then:
    - `port_free 9298` returns 1, and its output names `port-forward`.
    - `scenario_k8s_cleanup k-98-selftest` → `curl` to `localhost:9298` fails, and no `port-forward -n k-98-selftest` process remains.
  - `test_showdown_configmap`: `create_showdown_configmap k-97-selftest` produces a CM with keys `app.py` and `index.html`. Their sizes equal those of the source files.
- [ ] **Step 2: Run it.** `bash tests/scenarios/k8s-selftest.sh` → failures (no lib yet).
- [ ] **Step 3: Implement `tests/scenarios/k8s-cluster.sh`, and run `up`.** Then implement `kubernetes/scenarios/_lib.sh`, `tests/scenarios/k8s-lib.sh` and `tests/scenarios/k8s.sh` to the interfaces above.
- [ ] **Step 4: Run the self-test with `KUBECONFIG=$HOME/.kube/z2h-test.config`.** Everything is ✅. Then run shellcheck on all new files: no output.

---

### Scenario tasks (Tasks 2–16): the common recipe

Same as batch 1's recipe (`docs/superpowers/plans/2026-11-07-docker-break-fix-scenarios.md`, "Scenario tasks"), with these Kubernetes specifics:

- **Step 1: write the spec.** Write `tests/scenarios/k8s/NN.sh` (mode 644) with `NAMESPACES`, `broken()` and `fixed()`, using the task's assert lines verbatim. Use `in_cluster_http` for HTTP checks; the harness never port-forwards.
- **Step 2: watch it fail.** `./tests/scenarios/k8s.sh NN` → ❌.
- **Step 3: build the scenario.**
  - `git mv kubernetes/troubleshooting/<old> kubernetes/scenarios/<new>`. Rename `issue.yaml` → `break/app.yaml` and `fix.yaml` → `fix/app.yaml` (split into more files only if it helps the "what changed" diff). Replace `description.md` with `README.md`.
  - `cleanup.sh`: `need_cluster` is NOT called. If `kubectl get --raw /readyz` fails, it warns "Can't reach the cluster: nothing to clean up." and exits 0. Otherwise it calls `scenario_k8s_cleanup <ns...>`.
  - `break.sh`, in order:
    1. `need_cluster`
    2. `../cleanup.sh`
    3. `port_free 92NN`
    4. `fresh_ns`
    5. `create_showdown_configmap`, if the scenario uses Cats vs Dogs
    6. `kubectl apply -f break/`
    7. `wait_for` the intended failure, bounded at 180 s and reading `pod_reason` and `kubectl get` output
    8. `show_next`, with what the room sees and the first command (`kubectl get pods -n <ns>`)
  - `fix.sh`, in order:
    1. Apply `fix/`, or delete and re-apply objects whose fields are immutable (say so in a comment).
    2. `wait_for` Ready / the fixed state.
    3. `show_next "✅ Fixed. Now verify it yourself:" …`, which includes the `port-forward` line.
  - **"Visitor" Pods.** Where the scenario serves traffic, a small busybox `visitor` Pod requests the Service every 2 s and prints `✅ <time> HTTP 200` / `❌ <time> <error>`. The README uses `kubectl logs -f visitor -n <ns>` as the live stage signal; keep this from the old `ts-client`.
- **Step 4: README.**
  - 13 parts; all commands carry `-n <ns>`.
  - Verify includes the hand-typed `port-forward` (terminal 2) and the browser/curl check (terminal 1).
  - Add one line for playgrounds: open the URL for port 92NN.
- **Step 5:** `./tests/scenarios/k8s.sh NN` → ✅ (two cycles).
- **Step 6: rehearse by hand on the test cluster.** Run every README command in order, port-forward included, and paste the real output.
- **Step 7:** shellcheck on the scenario's scripts and spec: no output.

---

### Task 2: K01 `01-excalidraw-pending` (♻️ `01-pod-pending-insufficient-resources`)
- **App/port:** Excalidraw Deployment `draw` + Service `draw` (80), 9201. Namespace `k-01-pending`.
- **Break:** requests `memory: 64Gi, cpu: 100m` ("for the whole university").
- **Fix:** requests `64Mi`/`50m`, limits `128Mi`.
- **Assert broken:** `pod_reason k-01-pending app=draw` = `Pending`; `kubectl get events -n k-01-pending` contains `Insufficient memory`.
- **Assert fixed:** `wait_ready k-01-pending app=draw 120`; `in_cluster_http k-01-pending http://draw` = `200`.
- **Hook:** "We asked for a whiteboard. Kubernetes heard 'a data centre'."
- **Concept:** requests are reservations that the scheduler must fit on one node; limits are caps.
- **At work:** copy-pasted requests from a big service; Pending pods during a launch; cluster autoscaler triggers.
- **Investigate path:**
  1. `get pods` (Pending)
  2. `describe pod` (Events: `0/N nodes are available: … Insufficient memory`)
  3. `kubectl describe nodes | grep -A5 Allocatable` (or `kubectl get nodes -o custom-columns=…`)
- **Lifelong lesson:** "Pending is the scheduler saying no. Read the Events. It always says why."

### Task 3: K02 `02-image-typo` (♻️ `02-imagepullbackoff`)
- **App/port:** Excalidraw, 9202, `k-02-image-typo`.
- **Break:** image `excalidraw/excalidrw` (name typo; the digest stays).
- **Fix:** the correct name.
- **Assert broken:** `pod_reason` ∈ {`ErrImagePull`, `ImagePullBackOff`}; the events contain `pull`.
- **Assert fixed:** Ready + 200.
- **Hook:** "One missing letter. Kubernetes tries, waits, tries again… forever."
- **Concept:** the kubelet pulls on each node; back-off grows (10 s → 5 min); `ImagePullBackOff` means waiting to retry.
- **At work:** registry auth (`imagePullSecrets`), deleted tags, rate limits.
- **Investigate path:** `get pods` → `describe pod` (the pull error text) → `kubectl get deploy draw -o jsonpath='{..image}'`.
- **Lifelong lesson:** "BackOff means 'I'm waiting to retry'. The real error is in the Events."

### Task 4: K03 `03-showdown-crashloop` (♻️ `03-crashloopbackoff`)
- **App/port:** Cats vs Dogs (ConfigMap), Service `showdown` port 80 → 8080, 9203, `k-03-crashloop`.
- **Break:** env `PORT: "eighty"`. The app crashes with `ValueError` on start. Verify the real traceback text from `app.py`.
- **Fix:** `PORT: "8080"`.
- **Assert broken:** `pod_reason` = `CrashLoopBackOff` (allow `Error` while it's still early, but wait for `CrashLoopBackOff`); `kubectl logs --previous` contains `ValueError`.
- **Assert fixed:** Ready + `in_cluster_http … http://showdown/healthz` = 200.
- **Hook:** "It starts. It dies. It starts. It dies. Welcome to the loop."
- **Concept:** restartPolicy plus back-off; `logs --previous` reads the dead container.
- **At work:** a bad config value, a missing env var, a migrated database URL.
- **Investigate path:** `get pods` (RESTARTS climbing) → `describe pod` (Last State: Terminated, Exit Code 1) → `logs --previous` → `get deploy -o yaml | grep -A1 PORT`.
- **Lifelong lesson:** "When it keeps dying, ask the corpse: `logs --previous`."

### Task 5: K04 `04-it-tools-no-endpoints` (♻️ `04-service-selector-mismatch`)
- **App/port:** IT-Tools Deployment labelled `app: tools, tier: backend`; Service `tools` selects `app: tools, tier: frontend`; visitor Pod; 9204; `k-04-no-endpoints`.
- **Fix:** the selector uses `tier: backend`.
- **Assert broken:** the pods are Ready; `kubectl get endpointslices -n k-04-no-endpoints -l kubernetes.io/service-name=tools -o jsonpath='{..addresses}'` is empty; `in_cluster_http … http://tools` ≠ 200.
- **Assert fixed:** the endpoints are non-empty; 200; visitor logs show ✅ within 10 s.
- **Hook:** "Every Pod is Running. Every request fails."
- **Concept:** a Service finds Pods by labels; no match means no endpoints.
- **At work:** a Helm values typo; a renamed label in a refactor.
- **Investigate path:** visitor logs → `get pods --show-labels` → `get svc -o wide` (SELECTOR) → `get endpointslices`.
- **Lifelong lesson:** "Running is not the same as reachable."

### Task 6: K05 `05-excalidraw-wrong-port` (♻️ `05-wrong-target-port`)
- **App/port:** Excalidraw; Service `draw` port 80 → targetPort 8080 (wrong); visitor Pod; 9205; `k-05-wrong-port`.
- **Fix:** targetPort 80.
- **Assert broken:** the endpoints are non-empty AND `in_cluster_http … http://draw` = `000` (connection refused).
- **Assert fixed:** 200.
- **Hook:** "Endpoints exist. The Pod is fine. Still: connection refused."
- **Concept:** port (Service) vs targetPort (container); test layer by layer.
- **At work:** an image that moved its port; nginx-unprivileged listens on 8080.
- **Investigate path:**
  1. visitor logs
  2. `get endpointslices` (addresses are there!)
  3. `kubectl get svc draw -o jsonpath='{.spec.ports}'`
  4. `kubectl get pod -o jsonpath='{..containerPort}'`, or the image docs
  5. test the Pod IP directly from a debug pod
- **Lifelong lesson:** "Test one layer at a time: Pod, then Service, then the outside."

### Task 7: K06 `06-kanboard-never-ready` (♻️ `06-readiness-probe-failing`)
- **App/port:** Kanboard Deployment, readinessProbe httpGet `/healthz` port 80 (no such path); Service `board`; visitor; 9206; `k-06-never-ready`.
- **Fix:** a probe path that really returns 200 on Kanboard. Verify it, e.g. `/` or `/healthcheck.php`, and use the real one.
- **Assert broken:** the pod is Running, `READY 0/1`; events contain `Readiness probe failed`; the endpoints are empty.
- **Assert fixed:** Ready 1/1; 200 via the Service.
- **Hook:** "It's running. It's healthy. It just never gets any visitors."
- **Concept:** readiness gates traffic; liveness restarts. A failing readiness check is silent but blocks traffic.
- **At work:** a dependency check inside readiness; a wrong path after an upgrade.
- **Investigate path:** `get pods` (0/1) → `describe pod` (probe failed: 404) → `get endpointslices` (empty) → `kubectl exec … wget -qO- localhost/healthz`, or a debug pod.
- **Lifelong lesson:** "A probe is a promise. Test the URL it checks."

### Task 8: K07 `07-showdown-slow-start` (♻️ `07-liveness-kills-slow-start`)
- **App/port:** Cats vs Dogs with `STARTUP_DELAY: "20"`; livenessProbe `/healthz` with initialDelaySeconds 5, periodSeconds 5, failureThreshold 1; 9207; `k-07-slow-start`.
- **Fix:** add a startupProbe (`/healthz`, periodSeconds 5, failureThreshold 12) and keep the liveness probe as it is.
- **Assert broken:** restartCount ≥ 2 within 90 s, and the events contain `Liveness probe failed`.
- **Assert fixed:** Ready, and restartCount stays the same for 30 s after Ready.
- **Hook:** "A perfectly healthy app keeps getting killed, every 10 seconds."
- **Concept:** liveness vs startup probes; give slow starters a startupProbe.
- **At work:** Java/Spring warm-up; big model loading; database migrations at boot.
- **Investigate path:** `get pods -w` (restarts) → `describe pod` (killed: liveness failed) → `logs` ("simulating slow startup") → `get deploy -o yaml | grep -A6 livenessProbe`.
- **Lifelong lesson:** "Never let liveness judge an app that hasn't finished waking up."

### Task 9: K08 `08-ai-trainer-oomkilled` (♻️ `08-oomkilled`)
- **App:** an "AI trainer" `python:3.12-alpine` Deployment that allocates 150 MB in steps, printing epochs (match batch 1's D06 style). Limits 64Mi. `k-08-oomkilled`. No port.
- **Fix:** limit `256Mi` (request `200Mi`).
- **Assert broken:** `lastState.terminated.reason` = `OOMKilled`, or restarts with OOMKilled.
- **Assert fixed:** logs contain `model trained`, and there is no new OOMKilled.
  - The Deployment keeps restarting after a successful exit. Make the script then `sleep infinity`, so it stays Running and finished.
- **Hook / lesson:** mirror D06, Kubernetes flavour. Lifelong lesson: "Exit 137 means someone killed it. In Kubernetes, `describe` tells you who."
- **Investigate path:** `get pods` (OOMKilled/CrashLoop) → `describe pod` (Last State: OOMKilled, 137) → `logs --previous` (stops mid-epoch) → limits from `get deploy -o yaml`.

### Task 10: K09 `09-adminer-missing-secret` (♻️ `09-createcontainerconfigerror`)
- **App/port:** Adminer Deployment, env `ADMINER_DEFAULT_SERVER=db`, and env `DB_PASSWORD` from secretKeyRef `adminer-db/password`. The Secret is absent. 9209, `k-09-missing-secret`.
- **Fix:** create the Secret `adminer-db` with `password=change-me-123` (`fix/secret.yaml`).
- **Assert broken:** `pod_reason` = `CreateContainerConfigError`; events contain `secret "adminer-db" not found`.
- **Assert fixed:** Ready + 200.
- **Hook:** "The database tool won't even start. No logs. Nothing."
- **Concept:** the kubelet resolves env from Secrets/ConfigMaps before starting. If one is missing, the container is never created.
- **At work:** a Secret created in the wrong namespace; a typo in the key; a secret-manager sync lag.
- **Investigate path:** `get pods` → `logs` (none: the container never started) → `describe pod` (Events) → `get secrets -n …`.
- **Lifelong lesson:** "No logs? Then it never started. Read the Events."

### Task 11: K10 `10-kanboard-pvc-pending` (♻️ `10-pvc-pending`)
- **App/port:** Kanboard with a PVC `board-data` (1Gi), storageClassName `fast-ssd` (doesn't exist), mounted at `/var/www/app/data`. 9210, `k-10-pvc-pending`.
- **Fix:** a PVC without storageClassName, so the default class is used. Deleting and recreating the PVC is required, because its spec is immutable; `fix.sh` comments this.
- **Assert broken:** `kubectl get pvc board-data -n k-10-pvc-pending -o jsonpath='{.status.phase}'` = `Pending`; events contain `fast-ssd`; the pod is Pending.
- **Assert fixed:** PVC `Bound`; the pod is Ready; 200.
- **Hook:** "The task board is waiting for a disk that will never arrive."
- **Concept:** PVC → StorageClass → provisioner → PV; WaitForFirstConsumer.
- **At work:** copying manifests between clouds (gp3 vs standard); restoring backups to new clusters.
- **Investigate path:** `get pods` (Pending) → `describe pod` (unbound PVC) → `get pvc` → `describe pvc` (no StorageClass `fast-ssd`) → `get storageclass` (the default is marked).
- **Lifelong lesson:** "Follow the chain: Pod → PVC → StorageClass. The break is where the chain stops."

### Task 12: K11 `11-showdown-bad-rollout` (♻️ `11-bad-rollout`)
- **App/port:** Cats vs Dogs v1: 3 replicas, `APP_VERSION 1.0.0`, maxSurge 1, maxUnavailable 0, readiness `/readyz`, change-cause annotation. Visitor shows the `X-App-Version` header or the version from `/api/info`. 9211, `k-11-bad-rollout`.
- **Break:** `break.sh` applies v1, waits Ready, then applies v2 (`APP_VERSION 2.0.0` plus `PORT: "eighty"`, i.e. broken), with change-cause "v2 Friday release".
- **Fix:** `kubectl rollout undo deployment/showdown -n k-11-bad-rollout`, then wait.
- **Assert broken:** `kubectl rollout status --timeout=5s` fails; at least one new-RS pod is CrashLoopBackOff; `in_cluster_http` = 200 still (old pods serve).
- **Assert fixed:** all 3 pods Ready with version 1.0.0; the rollout history shows a new revision.
- **Hook:** "Friday, 6 PM. The release goes out. Nobody notices… because Kubernetes saved you."
- **Concept:** rolling updates, readiness gating, rollback, history.
- **At work:** canary/blue-green; Friday deploy freezes.
- **Investigate path:** visitor logs (still ✅, v1) → `get pods` (new ones crashing) → `rollout status` (stuck) → `rollout history` → `logs --previous` on a new pod.
- **Lifelong lesson:** "Ship with a way back. Rollback is a feature, not a failure."

### Task 13: K12 `12-showdown-dns-namespaces` (♻️ `12-dns-wrong-namespace`)
- **Apps/port:**
  - Redis Deployment + Service `redis` in `k-12-dns-data`.
  - Cats vs Dogs in `k-12-dns-app` with `REDIS_HOST=redis`.
  - Visitor in the app namespace; 9212.
- **Fix:** `REDIS_HOST=redis.k-12-dns-data.svc.cluster.local`.
- **Assert broken:** `in_cluster_http k-12-dns-app http://showdown/readyz` = `503`.
- **Assert fixed:** `/readyz` = 200; voting increments in `/api/results`.
- **Hook:** "Same cluster. Same name. 'Never heard of it.'"
- **Concept:** DNS names are namespace-scoped. A short name searches only your own namespace; use `<svc>.<ns>.svc.cluster.local`.
- **At work:** shared services (databases, caches) in platform namespaces.
- **Investigate path:**
  1. visitor or `/readyz` shows the error
  2. `logs`
  3. `kubectl exec … -- python -c "import socket;socket.gethostbyname('redis')"`, which fails
  4. `get svc -A | grep redis`
  5. `cat /etc/resolv.conf` in the pod (search domains)
- **Lifelong lesson:** "Names are local. Addresses are global. Use the full name across namespaces."
- `NAMESPACES="k-12-dns-app k-12-dns-data"`.

### Task 14: K13 `13-lockdown-blocks-dns` (♻️ `13-networkpolicy-blocks-dns`)
- **Apps:** Cats vs Dogs + Redis in `k-13-lockdown`, plus a NetworkPolicy "lockdown" on the app Pods (egress only to Redis port 6379, so DNS is blocked). Visitor; 9213.
- **Guard (spec §10.2):** before the break, `break.sh` runs a 5 s enforcement probe in a throwaway namespace `k-13-probe`:
  - It applies a deny-all-egress policy to a busybox pod and checks that `wget` to a test Service fails.
  - If egress still works, it cleans up and stops with: "This cluster doesn't enforce NetworkPolicy (e.g. Docker Desktop, default minikube). Use kind, Killercoda or iximiuz for this scenario."
  - It always deletes `k-13-probe`, and `cleanup.sh` deletes it too.
- **Fix:** add a DNS egress rule (UDP+TCP 53 to `namespaceSelector: kubernetes.io/metadata.name: kube-system`).
- **Assert broken:** `/readyz` 503; the app logs show a name-resolution error for `redis`.
- **Assert fixed:** `/readyz` 200; voting works.
- **Hook:** "Security hardened the network. Now nothing can find anything."
- **Concept:** NetworkPolicy egress default-deny once selected; DNS is traffic too (port 53 to CoreDNS).
- **At work:** zero-trust rollouts; compliance hardening sprints.
- **Investigate path:**
  1. visitor
  2. `logs` (can't resolve)
  3. `exec` nslookup or `gethostbyname` (fails)
  4. `exec` connect to the Redis Service IP:6379 (works!)
  5. `get networkpolicy -o yaml`
- **Lifelong lesson:** "When everything breaks at once, suspect the shared thing: DNS."
- `NAMESPACES="k-13-lockdown k-13-probe"`. The harness runs on kind; kindnet enforces NetworkPolicy. Verify this and record it.

### Task 15: K14 `14-leaderboard-bot-forbidden` (♻️ `14-rbac-forbidden`)
- **App:** "leaderboard bot", a `curlimages/curl` Pod with ServiceAccount `leaderboard-bot`. Every 5 s it calls the API (`/api/v1/namespaces/k-14-forbidden/pods`) with its token and prints `✅ found N players (pods)` / `❌ 403 Forbidden`. `k-14-forbidden`. No port.
- **Fix:** a Role (`get,list` on `pods`) and a RoleBinding to the SA (`fix/rbac.yaml`).
- **Assert broken:** bot logs contain `403`; `kubectl auth can-i list pods -n k-14-forbidden --as=system:serviceaccount:k-14-forbidden:leaderboard-bot` = `no`.
- **Assert fixed:** `can-i` = `yes`; the bot logs show ✅ within 15 s.
- **Hook:** "The bot has a valid ID card. The API still says: not allowed."
- **Concept:** authentication (who) vs authorisation (what); ServiceAccount + Role + RoleBinding; least privilege.
- **At work:** CI deployers, operators, monitoring agents.
- **Investigate path:** `logs -f bot` → read the 403 JSON message (names the verb, resource and SA) → `auth can-i … --as=…` → `get role,rolebinding -n …`.
- **Lifelong lesson:** "403 tells you exactly what's missing: verb, resource, who. Grant only that."

### Task 16: K15 `15-mystery-redis-port` (♻️ `15-service-links-env-collision`)
- **App:** keep the old mechanics: a `python:3.12-alpine` "score worker" that does `int(os.environ['REDIS_PORT'])`, plus a Service named `redis` in the same namespace. Kubernetes injects `REDIS_PORT=tcp://10.x.x.x:6379`, so `ValueError` → CrashLoop. Add a Redis Deployment behind the Service so the fix has something real to talk to. `k-15-mystery-env`.
- **Fix:** `enableServiceLinks: false` in the Pod spec (the README also mentions renaming the variable as the alternative).
- **Assert broken:** CrashLoopBackOff; `logs --previous` contains `invalid literal for int()` and `tcp://`.
- **Assert fixed:** Ready; logs show `worker connected to redis:6379`.
- **Hook:** "Nobody set REDIS_PORT. Kubernetes did."
- **Concept:** Docker-link-style service environment variables injected for every Service in the namespace.
- **At work:** the classic `REDIS_PORT`/`MYSQL_PORT` collisions; why many charts set `enableServiceLinks: false`.
- **Investigate path:** `get pods` → `logs --previous` (`tcp://…`) → `kubectl exec`, or a debug pod, `env | grep REDIS` → `get svc`.
- **Lifelong lesson:** "If a value surprises you, find out who set it. It might be the platform."
- Cross-link: the course's own app handles this already (`apps/api/app.py` comment). Mention it as "how we made our own app immune".

---

### Task 17: Track integration and migration

**Files:**
- Create: `kubernetes/scenarios/README.md`, `kubernetes/scenarios/IMAGES.md` (if it isn't already built up by tasks), `kubernetes/scenarios/preload.sh`
- Modify: `labs.sh` (k8s parts), `scripts/check-prereqs.sh` (IMAGES), `README.md`, `SHOWTIME.md`, `kubernetes/README.md`, and every file found by the Step 1 grep
- Delete: what remains of `kubernetes/troubleshooting/` (README.md)

- [ ] **Step 1: Test.**
  - `grep -rn "kubernetes/troubleshooting" --exclude-dir=.git --exclude-dir=docs .` must print nothing.
  - The Markdown link checker must print `problems: 0`. Use the batch 1 checker if it is no longer in the repo, re-created under the scratchpad.
- [ ] **Step 2:** run it, and see the matches.
- [ ] **Step 3: write `kubernetes/scenarios/README.md`**, mirroring `docker/scenarios/README.md`. It contains:
  - the lineup
  - the session flow
  - **port-forward how-to** (terminal 2; `--address 0.0.0.0` for playgrounds; Ctrl+C to stop)
  - platform notes:
    - kind / minikube / Docker Desktop / Killercoda / iximiuz
    - Play with Docker has no Kubernetes
    - K13 needs NetworkPolicy enforcement
    - K10 needs a default StorageClass
  - a panic card: `./cleanup.sh`; `kubectl get ns | grep '^k-'`; `pkill -f "port-forward -n k-"`; `./labs.sh k8s clean`
  - the instructor preload checklist
  - a dry-run checklist table (kind, minikube, Docker Desktop, Killercoda, iximiuz)
  - a one-line disambiguation: scenario K01–K15 vs labs K00–K18
- [ ] **Step 4: write `preload.sh`.**
  - It pulls every `IMAGES.md` image with `docker pull`.
  - Then, if the current context is `kind-*`, it runs `kind load docker-image <img> --name <cluster>`. If it is `minikube`, it runs `minikube image load <img>`.
  - It prints ✅/❌ per image and a total, and must be bash 3.2 safe.
- [ ] **Step 5: update `labs.sh` k8s parts.**
  - `K8S_DIR` → `kubernetes/scenarios`.
  - `list` takes titles from the README first line.
  - `k8s clean` runs every `kubernetes/scenarios/*/cleanup.sh`.
  - Remove the `k8s NN [fix]` run paths and the k8s menu entries; the menu points to `kubernetes/scenarios/README.md`.
  - Remove the now-unused k8s break/fix functions.
  - Git behaviour is unchanged.
- [ ] **Step 6:** extend `check-prereqs.sh` IMAGES with the new pins (keep the existing ones). Update every reference from Step 2, retargeting sentences accurately to the new scenario content.
- [ ] **Step 7: Cold-cluster full run.**
  - `tests/scenarios/k8s-cluster.sh down && tests/scenarios/k8s-cluster.sh up`, then `./tests/scenarios/k8s.sh` → 15/15 ✅.
  - Also `tests/scenarios/k8s-cluster.sh down && … up --single`, then `./tests/scenarios/k8s.sh` → 15/15 ✅, which proves the 1-node behaviour.
  - Then: `bash tests/scenarios/k8s-selftest.sh` all ✅, shellcheck clean, link checker `problems: 0`, and `./labs.sh list`.
  - Finally `tests/scenarios/k8s-cluster.sh down`, so the test cluster doesn't linger. Never touch other kind clusters.
- [ ] **Step 8:** report and stop. Don't merge or push; the owner approves.
