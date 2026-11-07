# Break · Investigate · Fix: 15 Docker + 30 Kubernetes scenarios

**Date:** 2026-11-07 · **Repo:** `docker-k8s-zero-to-hero` · **Status:** design, awaiting approval

## 1. Intent: why this exists

The first sessions covered Git and Docker fundamentals, and attendees absorbed them. The next series is a **hands-on ride**: in every scenario something real and recognisable breaks live on stage, the room investigates it together, the instructor fixes it, and everyone verifies it.

The model is the instructor's earlier repo, [troubleshoot-kubernetes-like-a-pro](https://github.com/vellankikoti/troubleshoot-kubernetes-like-a-pro): one folder per scenario, with a failure you create and a fix you apply. This repo goes further in three ways:
1. **Docker as well as Kubernetes:** 15 + 30 scenarios.
2. **Richer teaching:** each README is a full talk track (concept, real-world use, investigation path, takeaways, lifelong lessons). The reference repo's write-ups are about 15 lines.
3. **Apps people love:** VS Code, Jupyter, Excalidraw, IT-Tools, Kanboard, a Homer dashboard, a QR app, original mini-games, the course's own Cats vs Dogs app. The goal is that people remember the moment, the way people remember a keynote demo.

**Audience and stage:** absolute beginners (students, teachers, non-tech people) who now know the basics, in sessions of **1000+ attendees**. The instructor drives the demo; attendees follow along on their own machines. A failure that isn't the planned one, such as a port clash or a leftover container, is chaos in front of 1000 people, so **reliability is the top quality bar**, above polish.

## 2. Goals, non-goals, anti-goals

**Goals**
- 15 Docker and 30 Kubernetes scenarios, each in the layout of §4.
- Every scenario is fun, uses an app attendees recognise or enjoy, and produces a visible, unambiguous failure.
- Each scenario works the same on **macOS (Intel and Apple Silicon), Linux, Windows (WSL2 / Git Bash), iximiuz Labs, Killercoda and Play with Docker** (Docker scenarios only on Play with Docker, which has no Kubernetes).
- `cleanup.sh` makes every scenario safe to start, repeat, or abandon midway.
- Reuse what exists: the 10 Docker and 15 Kubernetes scenarios already tested in `docker/troubleshooting` and `kubernetes/troubleshooting` keep their tested failure mechanics and are re-skinned and restructured.

**Non-goals**
- No one-command "break + verify" runner for class. The instructor deliberately runs `break.sh`, investigates and verifies **by hand**: the instructor said a fully scripted flow feels robotic and nobody pays attention.
- No verify script. Verification is manual commands in the README, with the expected output shown.
- No cloud-only features (cloud load balancers, managed storage classes, cloud IAM).
- Not a rewrite of the Labs (D01–D11, K01–K18) or the Git track.

**Anti-goals** (failure even if it "works")
- A break that fails *differently* on different machines (e.g. CPU-architecture scenarios), or a fix that only works on one platform.
- A scenario that leaves anything behind that can break the next one (ports, containers, networks, node taints or labels, namespaces).
- Dry, generic examples ("app1", "my-service") instead of apps and stories people relate to.
- Walls of text. The README is a talk track: short, scannable, stage-friendly.

## 3. Platform and compatibility constraints

- **Scripts:** `bash` only, with commands available on all targets (`docker`, `kubectl`, `curl`, `grep`, `sed`, `awk`, `sleep`). No `jq`, `envsubst`, `timeout` (missing on macOS), GNU-only flags, or `sed -i` without a backup suffix. Scripts must pass `shellcheck -S warning`. Shebang `#!/usr/bin/env bash`, `set -u`; scripts are executable (`chmod +x`, committed with mode 755).
- **Windows:** run from WSL2 (preferred; Docker Desktop requires it anyway) or Git Bash. Line endings must stay LF: add a `.gitattributes` with `*.sh text eol=lf` and `*.yaml text eol=lf`.
- **Images:** every image must have **both linux/amd64 and linux/arm64** builds, pinned to an exact tag, and in K8s scenarios ideally **≤ ~400 MB**. Verified candidates (download size, both arches present, checked 2026-11-07):

  | App | Image | Size | Notes |
  |---|---|---|---|
  | Excalidraw whiteboard | `excalidraw/excalidraw` | 44 MB | nginx-based, runs as root (useful for the security scenarios) |
  | IT-Tools (80+ dev tools) | `corentinth/it-tools` | 24 MB | |
  | VS Code in browser | `codercom/code-server` | 380 MB | needs `PASSWORD` |
  | Jupyter Lab | `quay.io/jupyter/base-notebook` | 343 MB | runs as uid 1000; token via `--IdentityProvider.token` |
    | Homer / Homepage dashboards | `b4bz/homer`, `ghcr.io/gethomepage/homepage` | 7 / 84 MB | |
  | Kanboard | `kanboard/kanboard` | 33 MB | |
  | Gitea (own GitHub) | `gitea/gitea` | 71 MB | |
  | Adminer (DB UI) | `adminer` | 44 MB | |
  | whoami | `traefik/whoami` | 5 MB | shows which Pod answered |
  | Base images | `nginx:1.27-alpine`, `nginxinc/nginx-unprivileged:1.27-alpine`, `python:3.12-alpine`, `redis:7-alpine`, `postgres:16-alpine`, `busybox:1.36` | 2–116 MB | |
  | Course app | Cats vs Dogs Showdown (`apps/api`, `apps/frontend`) | small | built locally; K8s loads it with `scripts/load-image.sh` |

  Rejected: `pengbai/docker-supermario` (amd64 only, ~1 GB) and `stirlingtools/stirling-pdf` (~1 GB download, 3.4 GB on disk). They may appear in at most one or two **Docker** scenarios, marked "download before class" and added to `scripts/check-prereqs.sh --pull`. Never in Kubernetes scenarios. `docker-2048` is amd64 only: rejected.
- **Games:** where a scenario wants a game, use an **original** small HTML5 game written for this course (e.g. "Dosa Dash", "Filter Coffee Catch"), served by `nginx:1.27-alpine` with the HTML mounted from a ConfigMap (K8s) or a bind mount / small build (Docker). No custom image is needed, and it runs on every arch. Do not recreate existing commercial games.
- **Ports and access:**
  - Docker scenario `NN` publishes on host ports **`81NN`** (e.g. D-06 → 8106; a second container uses `82NN`), bound to all interfaces so playground URLs work.
  - Kubernetes scenarios are opened with `kubectl port-forward --address 0.0.0.0 svc/<name> 92NN:<port>` (K-07 → 9207), which works identically on kind, minikube, Docker Desktop, Killercoda and iximiuz. NodePort is not used (it depends on cluster setup).
  - Any app with a login gets the known password **`change-me-123`** (the D01 lesson from today: never `--auth none` on a public URL).
  - Every README has a one-line "open it on a laptop" and a one-line "open it on a playground" instruction.
- **Kubernetes cluster assumptions:** any conformant cluster with 1+ nodes and a default StorageClass. kind (repo config: 1 control-plane + 2 workers), minikube (1 node), Docker Desktop (1 node), Killercoda (2 nodes), iximiuz. Scenarios needing more nodes than exist must be written so the failure is the same on 1 or 3 nodes (e.g. anti-affinity with `replicas` = nodes + 1, computed in `break.sh`). metrics-server is needed only for the HPA scenario; its `break.sh` installs it if missing, with the flags kind needs.

## 4. Scenario layout (decided by the instructor)

```
docker/scenarios/NN-short-slug/          kubernetes/scenarios/NN-short-slug/
├── README.md                            ├── README.md
├── cleanup.sh                           ├── cleanup.sh
├── break/                               ├── break/
│   ├── break.sh                         │   ├── break.sh
│   └── (Dockerfile, compose.yaml,       │   └── (manifests: *.yaml)
│        app files…)                     └── fix/
└── fix/                                     ├── fix.sh
    ├── fix.sh                               └── (corrected manifests)
    └── (corrected files)
```

**Class flow:** instructor explains (README) → `cd break && ./break.sh` → investigates **by hand** with the README's commands → `cd ../fix && ./fix.sh` → **verifies by hand** → takeaways → `cd .. && ./cleanup.sh`.

**Script contracts**
- `cleanup.sh`: **idempotent and silent on success.** It removes exactly what this scenario creates, in any state (never started, half-broken, fixed), and ends with one `✅ Scenario NN cleaned up` line. It must never fail (no `set -e`; every delete is tolerant of "not found"). For K8s it also reverts any **node-level** change (taints, labels) and waits until the namespace is fully gone, so an immediate re-run works.
- `break.sh`:
  1. Calls `../cleanup.sh` first, so every run starts clean.
  2. Checks prerequisites with a friendly message: Docker running, cluster reachable, and the scenario's host port free. If the port is taken, it names the container or process using it and how to free it, instead of failing mysteriously.
  3. Creates the failure.
  4. **Waits until the failure is actually visible** (bounded wait with a clear message, no `timeout` binary).
  5. Prints a short "👀 What you should see now" block and the first command to run.
  It does **not** diagnose: investigating is the class's job.
- `fix.sh`: applies the corrected files (from `fix/`), waits until healthy, and prints "✅ Fixed. Now verify it yourself:" plus the first verification command. It does not run the verification.
- **Naming, so scenarios can never collide** even if a cleanup was skipped:
  - Docker: every container, network, volume and image built gets the prefix `dNN-` (e.g. `d06-jupyter`) and the label `z2h.scenario=dNN`.
  - Kubernetes: one namespace per scenario, `k-NN-slug` (e.g. `k-07-slow-start`); cluster-scoped objects and node changes carry the label `z2h.scenario=kNN`.
- A tiny shared helper (`docker/scenarios/_lib.sh`, `kubernetes/scenarios/_lib.sh`) provides colours, `say`, `wait_for`, `port_free` and `need_docker`/`need_cluster`, so each script stays short and readable on screen. Scripts must still read clearly when shown to the audience.

## 5. README template (every scenario)

A stage talk track, about 1–2 screens, in this order:

1. **Title + one-line hook**, e.g. *"Jupyter dies while training your AI model, and leaves no error."*
   Meta line: ⏱ minutes · level · app used · concepts.
2. **📖 The story:** 2–4 sentences, a real-feeling moment (a hackathon, an exam-week assignment portal, a campus fest app, a startup's launch day). Bengaluru and college flavour where natural, as elsewhere in the course.
3. **🧠 The concept: why, what, how:** why this mechanism exists, what it is, how it works, in plain words with one analogy. 5–8 lines max, optionally one small diagram.
4. **🏢 Where you'll meet this at work:** 2–3 concrete real-world situations (e.g. "a Black Friday deploy", "a bank's nightly batch job", "a CI runner") and which role meets it (developer, SRE, platform team).
5. **💥 Break it:** `cd break && ./break.sh`, then what the room should see.
6. **🔍 Investigate:** the commands to run **in order**, each with one line on *why this one next* and what to look for in its output (expected output snippets shown). Hints in a folded `<details>` before the answer, so the room can guess first.
7. **🩺 Root cause:** folded, revealed after the room guesses.
8. **🔧 Fix it:** `cd ../fix && ./fix.sh`, plus the manual fix (the one-line command or the diff between `break/` and `fix/` files), so people see what changed.
9. **✅ Verify it yourself:** manual commands with expected output, e.g. open the app, `docker inspect …`, `kubectl get …`.
10. **🎯 Key takeaways:** 3–4 bullets.
11. **💎 Lifelong lesson:** one memorable, quotable sentence: the habit or principle worth a whole career (e.g. *"Running is not the same as reachable."*).
12. **🧹 Clean up:** `cd .. && ./cleanup.sh`.
13. **Next →** the next scenario.

Tone: keynote-energy, warm, no jargon without a one-line explanation. Analogies reuse the course's established ones where they fit (breakfast cafe, room / floor manager, hotel).

## 6. The lineup

♻️ = existing tested scenario, restructured and re-skinned (keep its failure mechanics) · 🆕 = new.

### 🐳 Docker (`docker/scenarios/`)
| # | Concept | Fun version | Source |
|---|---|---|---|
| 01 | Container exits immediately | 📓 Jupyter vanishes on start (typo in its start command) | ♻️ D-01 |
| 02 | Port already allocated | 🎨 Excalidraw and 🧰 IT-Tools fight over one port | ♻️ D-02 |
| 03 | App can't reach its database | 🐱🐶 Cats vs Dogs can't find Redis | ♻️ D-03 |
| 04 | Missing environment variable | 💻 VS Code says "incorrect password" (no `PASSWORD`) | ♻️ D-04 |
| 05 | Image not found | 🎨 typo in the Excalidraw image name or tag | ♻️ D-05 |
| 06 | OOM-killed (exit 137) | 📓 Jupyter dies mid "AI model training" | ♻️ D-06 |
| 07 | Volume permission denied | 📓 Jupyter can't save your notebook (uid 1000 vs root-owned folder) | ♻️ D-07 |
| 08 | Container unhealthy | 🧰 IT-Tools health check hits the wrong path | ♻️ D-08 |
| 09 | No DNS on the default bridge | 🏠 a Homer dashboard can't reach Excalidraw and IT-Tools by name | ♻️ D-09 |
| 10 | Build fails: `.dockerignore` | 🔳 build your own QR code app, but the code is ignored | ♻️ D-10 |
| 11 | App listens on 127.0.0.1 inside the container | 🌐 a portfolio site: works inside, unreachable outside | 🆕 |
| 12 | Container ignores `docker stop` (PID 1 / signals) | 🎮 game server loses your high score | 🆕 |
| 13 | Bind mount hides the image's files | 🌐 your portfolio website "disappears" | 🆕 |
| 14 | Secret baked into an image layer | 🔑 leaked API key found with `docker history` | 🆕 |
| 15 | Compose start order (`depends_on` without a health check) | 🐘 app starts before Postgres is ready | 🆕 |

### ☸️ Kubernetes (`kubernetes/scenarios/`)
| # | Concept | Fun version | Source |
|---|---|---|---|
| 01 | Pending: insufficient resources | 🎨 "Excalidraw for the whole university" requests 64 GB of RAM | ♻️ K-01 |
| 02 | ImagePullBackOff | 🎨 typo in the Excalidraw image | ♻️ K-02 |
| 03 | CrashLoopBackOff | 🐱🐶 Cats vs Dogs crashes on start (bad config value) | ♻️ K-03 |
| 04 | Service selector mismatch | 🧰 IT-Tools Pods Running, Service has no endpoints | ♻️ K-04 |
| 05 | Wrong targetPort | 🎨 Excalidraw Service points at 8080, the app listens on 80 | ♻️ K-05 |
| 06 | Readiness probe failing | 📋 Kanboard never becomes Ready (probe checks the wrong path) | ♻️ K-06 |
| 07 | Liveness kills a slow starter | 🐱🐶 Cats vs Dogs "warming up" for 20 s gets killed before it's ready (fix: startupProbe) | ♻️ K-07 |
| 08 | OOMKilled | 🤖 an "AI training" Pod (python:alpine) over its memory limit | ♻️ K-08 |
| 09 | CreateContainerConfigError | 🗄️ Adminer's database-password Secret doesn't exist | ♻️ K-09 |
| 10 | PVC Pending | 📋 Kanboard's data volume asks for a StorageClass that doesn't exist | ♻️ K-10 |
| 11 | Bad rollout + rollback | 🐱🐶 Cats vs Dogs v2 ships broken; `rollout undo` | ♻️ K-11 |
| 12 | DNS across namespaces | 🐱🐶 frontend calls `redis` that lives in another namespace | ♻️ K-12 |
| 13 | NetworkPolicy blocks DNS | 🔒 a "lockdown" policy breaks name lookups | ♻️ K-13 |
| 14 | RBAC forbidden | 🤖 a leaderboard bot's ServiceAccount can't list Pods | ♻️ K-14 |
| 15 | Service-link env collision | 🐱🐶 `REDIS_PORT=tcp://…` crashes the app | ♻️ K-15 |
| 16 | Taints and tolerations | 🎮 game server refused by a "VIP-only" node | 🆕 |
| 17 | nodeSelector / node affinity mismatch | 🤖 the "AI trainer" wants a `gpu=true` node that doesn't exist | 🆕 |
| 18 | Required pod anti-affinity | one replica more than nodes: "never two on the same node" | 🆕 |
| 19 | ResourceQuota exceeded | 🏁 hackathon namespace: Deployment creates zero Pods (reason only in ReplicaSet events) | 🆕 |
| 20 | LimitRange defaults too small | surprise OOM from defaults nobody wrote | 🆕 |
| 21 | `runAsNonRoot` vs a root image | 🔐 security policy blocks Excalidraw (fix: unprivileged image) | 🆕 |
| 22 | Read-only root filesystem | app crashes writing its cache (fix: `emptyDir` for writable paths) | 🆕 |
| 23 | ConfigMap change not picked up | 🎨 "dark mode" flipped in the ConfigMap, the app still shows light (env vars need a restart) | 🆕 |
| 24 | Wrong command / args | `RunContainerError`: executable not found | 🆕 |
| 25 | HPA not scaling | 📈 `<unknown>` targets: no CPU requests / no metrics | 🆕 |
| 26 | Init container stuck | 🐱🐶 Cats vs Dogs waits forever for a Redis Service that has a typo (`Init:0/1`) | 🆕 |
| 27 | Volume mount fails | missing ConfigMap key → stuck `ContainerCreating` (`FailedMount`) | 🆕 |
| 28 | Job fails | 🏆 the midnight leaderboard reset hits `BackoffLimitExceeded` | 🆕 |
| 29 | Multi-container Pod `1/2 Ready` | a broken sidecar; teaches `kubectl logs -c` | 🆕 |
| 30 | Finale: "The Friday 5 PM outage" | three faults at once, fixed by the room as a team | 🆕 |

Deliberately excluded (break differently per machine or need cluster add-ons): wrong CPU architecture, Ingress/Gateway, PodDisruptionBudget drains, cluster autoscaler.

## 7. Reuse and migration

- **Move, don't fork:** `docker/troubleshooting/NN-*` → `docker/scenarios/NN-*` and `kubernetes/troubleshooting/NN-*` → `kubernetes/scenarios/NN-*`, using `git mv` to keep history. Content is rewritten to the template; the failure mechanics stay.
- **The Git track's troubleshooting stays as it is** (`git/troubleshooting`, already break/fix-scripted); it's out of scope.
- **`labs.sh`:** keep it as an optional helper for listing scenarios and **clean-all** (`./labs.sh docker clean` runs every scenario's `cleanup.sh`), updated to the new paths. It is no longer the in-class way to run a scenario.
- **Update all references:** root README, `docker/README.md`, `kubernetes/README.md`, SHOWTIME.md (the "Gauntlet"), lab READMEs that link to scenarios (e.g. D-06 ↔ K-08), cheat sheets, and `scripts/check-prereqs.sh --pull` (add the new images).
- Each track gets a `scenarios/README.md` index: the lineup table, how a session runs (§4 flow), platform notes, and the "if something goes wrong on stage" panic card (run `./cleanup.sh`, check the port, re-run `break.sh`).

## 8. Definition of done (per scenario)

1. `break.sh` → expected failure is visible; README's investigation commands show what the README says.
2. `fix.sh` → healthy; README's verification commands show the expected output.
3. `cleanup.sh` → nothing left (`docker ps -a --filter label=z2h.scenario=dNN` empty / namespace gone, node taints and labels reverted).
4. The whole cycle runs **twice in a row** with no manual intervention, and `cleanup.sh` succeeds when run on an already-clean system.
5. Tested on **Docker Desktop (macOS arm64)** and a **kind cluster (1 control-plane + 2 workers)**. The K8s scenarios that depend on node count are also tested on a **single-node** kind cluster.
6. `shellcheck -S warning` clean; Markdown link check clean; images pinned and listed in `check-prereqs.sh`.
7. Platforms not testable from the build machine (Windows/WSL2, Linux, Killercoda, iximiuz, Play with Docker) get a **dry-run checklist** in `scenarios/README.md` for the instructor to run before class.

## 9. Delivery order

Docker 01–15 first (the next sessions start there), then Kubernetes 01–15 (the ♻️ ones), then Kubernetes 16–30. Each batch is committed and pushed only when the instructor says "Commit & push", following the convention in this repo.

## 10. Decisions from the design review (builder check)

Calls made by the designer (Claude) to settle questions a builder would otherwise have to guess. The instructor can override any of them.

1. **Images reach machines through a preload step + a safe fallback.**
   - Each track gets `scenarios/preload.sh`: it pulls every image the track uses and, for Kubernetes, loads it into kind or minikube nodes when those are detected. It prints a ✅/❌ list.
   - `break.sh` never assumes an image is local. If one is missing, it says "downloading X (N MB) for the first time…" and pulls it with progress visible, so a slow pull looks intentional rather than broken.
   - *(The instructor's answer on attendee preloading is recorded in §11.)*
2. **K-13 (NetworkPolicy) keeps its place, with a guard.** `break.sh` first checks whether the cluster enforces NetworkPolicy (a 5-second deny probe between two throwaway Pods). If it doesn't (Docker Desktop, default minikube), it stops with a friendly "this cluster doesn't enforce NetworkPolicy: use kind or Killercoda for this one" message. Supported on kind (kindnet enforces), Killercoda and iximiuz.
3. **K-25 (HPA) and metrics-server:** `break.sh` installs metrics-server only if it's missing, and records that by labelling it `z2h.scenario=k25-installed`. `cleanup.sh` removes it **only** if that label is present, so a cluster that already had metrics-server (or the K13 lab's install) is never touched.
4. **No locally built images in Kubernetes scenarios.** The Cats vs Dogs app is Python standard library, so K8s scenarios run it from the public `python:3.12-alpine` image with the app code mounted from a ConfigMap (the frontend from `nginx:1.27-alpine` + ConfigMap). There's no image building or node loading, so it works the same on single- and multi-node clusters. Docker scenario D-03 may still `docker build` locally.
5. **Re-skins may change the mechanics; every ♻️ scenario is fully re-validated.** Each failure must reproduce the same way on Docker Desktop (macOS) and Linux. In particular:
   - D-06 (OOM) sets the memory limit relative to the app's measured baseline.
   - D-07 (permissions) uses a **named volume** pre-owned by root, not a bind mount, because macOS bind mounts don't reproduce Linux ownership errors.
6. **Old folders are moved, not kept.**
   - `docker/troubleshooting` and `kubernetes/troubleshooting` are replaced by `docker/scenarios` and `kubernetes/scenarios` (`git mv`, history kept).
   - Every link in the repo is updated (link check must pass).
   - `labs.sh` keeps only `list` and `clean` (clean-all runs each `cleanup.sh`) for the Docker and Kubernetes tracks. Its old `labs.sh <track> NN [fix]` scenario commands are removed. The Git track's `labs.sh git …` commands are unchanged.
7. **`kubectl port-forward` is always run by hand, in the foreground** in a second terminal (Ctrl+C to stop), exactly as the README shows. As a safety net, `cleanup.sh` also stops any leftover `kubectl port-forward` for its namespace.

## 11. Instructor decisions

- **Images download live, on venue Wi-Fi** (attendees do not preload). This is the biggest reliability risk, so image size becomes a hard rule:
  - **Kubernetes scenarios: only images ≤ ~60 MB.** Allowed: `excalidraw/excalidraw` (44), `corentinth/it-tools` (24), `kanboard/kanboard` (33), `b4bz/homer` (7), `traefik/whoami` (5), `adminer` (44), `nginx:1.27-alpine` / `nginxinc/nginx-unprivileged:1.27-alpine` (22), `python:3.12-alpine` (19, also runs Cats vs Dogs and the course's mini apps from ConfigMaps), `redis:7-alpine` (17), `busybox:1.36` (2). **No Jupyter, VS Code or Uptime Kuma in Kubernetes**; their stories move to the light apps above (see the updated lineup).
  - **Docker scenarios:** the heavy stars are limited to **Jupyter** (D-01, D-06, D-07 share one 343 MB download) and **VS Code** (D-04, 380 MB). Everything else stays ≤ ~160 MB. Jupyter is downloaded in the **first** scenario that uses it, so later ones reuse the cache.
  - **Reuse beats variety:** a track should download as few distinct images as possible. Prefer an image already used earlier in the track over a new one of similar fun value.
  - Each README's meta line shows the download size and a "⬇️ first time only" note when a scenario introduces a new image. `preload.sh` (§10.1) still exists for instructors and anyone who wants to download at home.
  - The instructor's own machine is preloaded the day before (instructor checklist in `scenarios/README.md`), so **the stage demo never waits on Wi-Fi**, even when attendees' downloads are slow.

## 12. Left to the builder

- Exact image tags (pin the latest stable that has both arches), the app chosen for scenarios marked with a generic description, and story wording.
- Scenario slugs (short, kebab-case, e.g. `06-jupyter-oom-killed`).
- The original HTML5 games' content (small, original, Bengaluru-flavoured).
- Whether a scenario needs a small diagram.
