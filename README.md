# 🌿 🐳 ☸️ Git, Docker & Kubernetes: Zero to Hero

**From your first `git commit` to running a hardened, self-healing, autoscaling app on Kubernetes, with a live audience voting on it from their phones.**

Hands-on labs for complete beginners: students, teachers, career-switchers, and non-tech professionals. Everything runs on **Docker Desktop**, **kind**, **minikube**, or a free browser sandbox like **Killercoda**. No cloud account needed.

```
  🕵️ Find who set benne dosa to ₹1 at Vidyarthi Bhavan, then hunt a bug with git bisect in seconds
  🍄 Play Mario from a container in 3 seconds
  🐱🐶 Build & ship a live voting app the whole room uses from their phones
  💀 Delete every server and watch Kubernetes bring them back
  🦄 "One more thing…": release a new version mid-vote with 0 failed requests
  🔥 Break things on purpose, 68 times, and fix them like a pro
```

---

## 🎯 Who this is for
- **Never touched a terminal?** Start at [00-setup](00-setup/README.md), then **Track 0 · Git** ([G00](git/00-foundations/README.md)), then [D00 Docker Foundations](docker/00-foundations/README.md). Each track opens with the why and how, using stories and diagrams, before any command. Every command after that is given and explained.
- **Used Docker a bit?** Jump to [D05 production Dockerfiles](docker/05-production-dockerfiles/README.md) or [Kubernetes K01](kubernetes/01-cluster-tour/README.md).
- **Teaching this?** Read [🎤 SHOWTIME.md](SHOWTIME.md), a keynote-style run-of-show with timings, lines, and "wow" moments.

## 🐱🐶 The star of the show: *The Showdown*
Every lab uses one small, fun app: a **live voting app** ([`apps/`](apps/)).

| What you see in the browser | What it teaches |
|---|---|
| **"Served by"** card | which container or Pod answered: load balancing, made visible |
| **Pod wall** of coloured tiles | scaling, self-healing, rolling updates, all live |
| **💥 Crash this server** button | chaos engineering; restart policies and Kubernetes self-healing |
| **Live health** counter (OK / failed) | proof of zero-downtime deployments |
| **Storage badge**: memory vs Redis | why state must live outside containers |
| **"One more thing…"** banner | new versions and config changes rolling out |

It's ~250 lines of standard-library Python plus one HTML page: no frameworks, no `pip install`, nothing to distract from Docker and Kubernetes.

## 🗺️ The journey

### 🌿 Track 0: Git ([overview](git/README.md)): where every change begins
| Lab | You will… | Wow moment |
|---|---|---|
| [G00](git/00-foundations/README.md) ⭐ | **foundations**: why version control, commits, branches, remotes, the team workflow (9 diagrams + quiz) | 🗺️ the "which undo do I need?" map |
| [G01](git/01-first-repo/README.md) | init, add, commit, log, diff | your first save point |
| [G02](git/02-time-travel-undo/README.md) | blame, revert, restore, amend, reflog | 😱 "who set benne dosa to ₹1?" |
| [G03](git/03-branches/README.md) | branches, fast-forward vs merge commit | files change as you switch branches |
| [G04](git/04-teamwork-remote/README.md) | remotes, push, pull, fetch | 💥 the rejected push |
| [G05](git/05-merge-conflicts/README.md) | resolving conflicts | 🥞⚔️ the ghee roast dosa price war |
| [G06](git/06-pull-requests/README.md) | pull requests, review, CI checks | 🤖 a robot catches the ₹2600 typo |
| [G07](git/07-release-and-incident/README.md) | tags, semver, bisect, hotfix | 🚨 find the guilty commit among many in seconds |
| [🔥 G-scenarios](git/troubleshooting/README.md) | **8 Git emergencies** | |


### 🐳 Track 1: Docker ([overview](docker/README.md))
| Lab | You will… | Wow moment |
|---|---|---|
| [D00](docker/00-foundations/README.md) ⭐ | **foundations**: why containers exist, VM vs containers, Docker architecture, namespaces, cgroups, layers (12 diagrams + 50-question quiz) | 🤯 two Linux distros, one kernel |
| [D01](docker/01-first-steps/README.md) | install check, first containers, **Image Arcade** | 🍄 Mario in your browser in one command |
| [D02](docker/02-images-containers-lifecycle/README.md) | images vs containers, lifecycle, exit codes | why containers "die immediately" |
| [D03](docker/03-inside-containers/README.md) | ports, logs, exec, inspect | 📱 the room votes; 💀 votes vanish |
| [D04](docker/04-first-dockerfile/README.md) | write Dockerfiles, env config | 🎩 one image → three different apps |
| [D05](docker/05-production-dockerfiles/README.md) | multi-stage, caching, PID 1, scanning | 1.3 GB → 13 MB; 10-second stop → instant |
| [D06](docker/06-volumes/README.md) | volumes, bind mounts, backups | 💾 destroy everything, votes survive |
| [D07](docker/07-networking/README.md) | networks, DNS, the `localhost` trap | 🧱 kill a server, 0 failed requests |
| [D08](docker/08-compose/README.md) | Docker Compose, scaling, segmentation | 🦄 "one more thing…" |
| [D09](docker/09-health-restart/README.md) | health checks, restart policies | 💥 press the red button |
| [D10](docker/10-registry-tags/README.md) | registries, tags, digests | why `latest` bites |
| [D11](docker/11-limits-security/README.md) | limits, OOM, non-root, hardening | the fully hardened `docker run` |
| [🔥 Docker scenarios](docker/scenarios/README.md) | **15 break-and-fix incidents** | |

### ☸️ Track 2: Kubernetes ([overview](kubernetes/README.md))
| Lab | You will… | Wow moment |
|---|---|---|
| [K00](kubernetes/00-foundations/README.md) ⭐ | **foundations**: why orchestration, architecture as a container port, desired state & reconciliation (9 diagrams + 50-question quiz) | ⎈ try to out-delete the controller |
| [K01](kubernetes/01-cluster-tour/README.md) | cluster tour, kubectl essentials | Kubernetes runs on Kubernetes |
| [K02](kubernetes/02-pods/README.md) | Pods, init containers, sidecars | CrashLoopBackOff, live |
| [K03](kubernetes/03-namespaces-labels/README.md) | namespaces, labels, selectors | labels are the glue |
| [K04](kubernetes/04-deployments/README.md) | Deployments, self-healing, scaling | 💀 delete every Pod; they come back |
| [K05](kubernetes/05-services/README.md) | Services, DNS, NodePort/LB | 💥 one typo takes the whole room down |
| [K06](kubernetes/06-rollouts/README.md) | rolling updates, rollback | 🎤 **new version mid-vote, 0 failures** |
| [K07](kubernetes/07-config-secrets/README.md) | ConfigMaps, Secrets | 🥞 change tonight's poll live |
| [K08](kubernetes/08-probes/README.md) | startup / liveness / readiness | the probe that kills healthy apps |
| [K09](kubernetes/09-resources-qos/README.md) | requests, limits, QoS, quotas | Pending: "Insufficient cpu" |
| [K10](kubernetes/10-storage-statefulsets/README.md) | PVCs, StatefulSets | databases that keep their identity |
| [K11](kubernetes/11-jobs-cronjobs/README.md) | Jobs, CronJobs | |
| [K12](kubernetes/12-gateway-ingress/README.md) | Gateway API, canary releases | 🦄 watch 10% of traffic flicker to v2 |
| [K13](kubernetes/13-autoscaling/README.md) | HPA, metrics-server | 📈 the Pod wall grows by itself |
| [K14](kubernetes/14-rbac/README.md) | RBAC, ServiceAccounts | 403 Forbidden, explained |
| [K15](kubernetes/15-network-policies/README.md) | NetworkPolicies | 🕵️ block the intruder |
| [K16](kubernetes/16-pod-security/README.md) | securityContext, Pod Security | the API server says no |
| [K17](kubernetes/17-scheduling/README.md) | affinity, taints, PDBs, drain | node maintenance with zero downtime |
| [K18 🏆](kubernetes/18-capstone/README.md) | **capstone: production-grade deploy** | 🔥 the Gauntlet: chaos vs your platform |
| [🔥 Kubernetes scenarios](kubernetes/scenarios/README.md) | **45 break-and-fix incidents** (K01–K45) | |

## 🚀 Quick start
```bash
git clone https://github.com/vellankikoti/docker-k8s-zero-to-hero.git
cd docker-k8s-zero-to-hero
./scripts/check-prereqs.sh            # are you ready?

docker build -t z2h/api:1.0 apps/api
docker run -d --name showdown -p 8080:8080 z2h/api:1.0
open http://localhost:8080            # 🐱 vs 🐶  (Linux: xdg-open; or just open the URL in a browser)
```

## 🔥 The Troubleshooting Arena
```bash
./labs.sh            # interactive menu: the Git scenarios (Docker and Kubernetes ones are run by hand)
./labs.sh list       # every scenario, by track
```
Docker and Kubernetes scenarios are run by hand from their folders: see [docker/scenarios/README.md](docker/scenarios/README.md) and [kubernetes/scenarios/README.md](kubernetes/scenarios/README.md). `./labs.sh docker clean` and `./labs.sh k8s clean` reset them all.

68 real-world incidents (8 Git, 15 Docker, 45 Kubernetes): committed secrets, rejected pushes and lost commits in Git; leaked keys and vanishing data in Docker; crash loops, OOM kills, DNS failures, broken selectors, RBAC denials, NetworkPolicy outages, stuck rollouts, and more. Each has a story, symptoms, hints, and a hidden answer. Then level up with 35 more in [troubleshoot-kubernetes-like-a-pro](https://github.com/vellankikoti/troubleshoot-kubernetes-like-a-pro).

## 📁 Repository layout
```
docker-k8s-zero-to-hero/
├── SHOWTIME.md              🎤 instructor run-of-show
├── 00-setup/                Docker Desktop · kind · minikube · Killercoda
├── apps/
│   ├── api/                 🐱🐶 the Showdown app (Python stdlib + one HTML page)
│   └── frontend/            nginx reverse proxy tier
├── git/                     G00–G07 + troubleshooting/ (8 scenarios) + scripts/lab-start.sh
├── docker/                  D00–D11 + scenarios/ (15 scenarios)
├── kubernetes/              K00–K18 + stack/ (shared manifests) + scenarios/ (39 scenarios)
├── cheatsheets/             git.md · docker.md · kubectl.md
├── scripts/                 check-prereqs.sh · load-image.sh
└── labs.sh                  🔥 Git scenario runner + `docker clean` / `k8s clean`
```

## 🧭 How every lab is built
🎯 what you'll learn → 🧠 the concept in 60 seconds → 🧪 hands-on steps with expected output → 🏭 what changes in production → 🏆 challenge → ✅ checkpoint quiz (answers hidden) → 🧹 cleanup

## 📚 Cheat sheets
[Git](cheatsheets/git.md) (checkout *and* switch) · [Docker](cheatsheets/docker.md) · [kubectl](cheatsheets/kubectl.md)

---
*Built to accompany the Christ University DevOps course (Units 1–3). Learn the **why**, then the command.*
