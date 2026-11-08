# 🔥 Kubernetes break-and-fix scenarios

15 stage demos. Each one **breaks something in a cluster on purpose**, the class investigates by hand with `kubectl`, then a fix script repairs it. Every scenario has its own folder with a story, the concept, the commands to type, and takeaways.

> **Scenarios vs labs.** Here **K01–K15 means scenario folders** in this directory. They are not the labs K00–K18 in the [Kubernetes track](../README.md). Scenarios 16–30 come in a later batch.

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

Scenario `NN` uses local port `92NN` (the apps you can open in a browser). Each scenario lives in its own namespace named `k-NN-<slug>` (K12 uses two, K13 also creates a short-lived `k-13-probe`), so nothing touches your lab work. Logins: Kanboard (K06, K10) uses the default `admin` / `admin`; the other apps need no login (Adminer in K09 only shows its login form, and there is no database behind it). All images and sizes are in [IMAGES.md](IMAGES.md).

## How a session runs

1. **Instructor explains**: read the story and the concept in the scenario's `README.md`.
2. **Break it**: `cd break && ./break.sh`
3. **Investigate by hand**: the class types the commands from the README. `break.sh` never explains the cause, that is the class's job. In scenarios with a small `visitor` Pod (K01–K07, K09–K13) open a **second terminal** and run `kubectl logs -f visitor -n <namespace>` (the README gives the exact line) to watch the app fail as a user sees it.
4. **Fix it**: `cd ../fix && ./fix.sh`. If the visitor log is open, the live ❌ → ✅ moment is the best part of the demo.
5. **Verify by hand**: the class checks it really works. `fix.sh` does not verify for you. To open an app, use a **second terminal**:
   ```bash
   kubectl port-forward -n <namespace> svc/<service> 92NN:<port>
   ```
   The scenario README prints the exact line (for example K07: `kubectl port-forward -n k-07-slow-start svc/showdown 9207:80`). Then open `http://localhost:92NN` on a laptop. On a playground, add `--address 0.0.0.0` and open the URL for port `92NN`. Press **Ctrl+C** in that terminal to stop it. K08, K14 and K15 have no web page: you verify them in the terminal.

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

- **Check your cluster first.** `kubectl config current-context` shows which cluster you are about to break. The scenarios only create things in their own `k-NN-...` namespaces, but break the right cluster on purpose.
- **K10 needs a default StorageClass.** `kubectl get storageclass` must show one marked `(default)`. K10's fix is to stop asking for the missing `fast-ssd` class and use that default.
- **K01, K02 and K10 download their app at fix time**, because the Pod never starts while it is broken (K01, K02: Excalidraw; K10: Kanboard). On a cold cluster the fix waits on that download (the first time it can take up to a minute or two): preload it or run the scenario once before class (see the checklist below).
- **K13 needs a cluster that enforces NetworkPolicy**, and checks it first (a throwaway `k-13-probe` namespace, deleted straight after). If your cluster ignores policies, it stops with a clear message instead of showing a fake outage.
- **Scenarios behave the same on 1 node and 3 nodes** (minikube and Docker Desktop are one node; the course's kind config is three).

Scripts need only `bash`, `kubectl`, `curl` and ordinary Unix tools. No `jq`, no `helm`.

## 🆘 PANIC CARD (when something goes wrong on stage)

Stay calm. Nothing here touches anything outside the `k-NN-...` namespaces. In this order:

1. **Reset the scenario:** `./cleanup.sh` (from the scenario folder). It is safe at any time, even if nothing is running, and it waits until the namespace is really gone.
2. **Look at what is left:** `kubectl get ns | grep '^k-'`. Anything listed is a scenario namespace; delete one with `kubectl delete ns <name>`.
3. **Port already in use?** An old port-forward is still running: `pkill -f "port-forward -n k-"` (or press Ctrl+C in its terminal).
4. **Run it again:** `./break.sh` again. It starts clean every time.
5. **Still odd? Reset everything:** `./labs.sh k8s clean` from the repo root. It runs every scenario's `cleanup.sh` against your current cluster.

`The connection to the server ... was refused` or `no cluster`? Start Docker Desktop / minikube / kind, check `kubectl config current-context`, then step 4.

## Instructor preload checklist

- [ ] **Check which cluster you are on:** `kubectl config current-context`. The preload loads images into the cluster of the **current** context, so make sure it is the demo cluster.
- [ ] **The day before**, on good Wi-Fi: `./kubernetes/scenarios/preload.sh`. It pulls every image in [IMAGES.md](IMAGES.md) (about 240 MB download) with Docker, and prints ✅/❌ per image and a total. If the current context is `kind-<name>` it also runs `kind load docker-image` into that cluster, and for `minikube` it runs `minikube image load`. Other clusters (Docker Desktop, Killercoda, iximiuz) download images when a Pod first starts, so run each scenario once there instead.
- [ ] **Then run every scenario once** (break, fix, cleanup), so you have seen each output on your own machine.
- [ ] On the morning: `kubectl get ns | grep '^k-'` prints nothing (or run `./labs.sh k8s clean`), and no leftover `kubectl port-forward` is running.

## Playground dry-run checklist

Tick each cell after you have run the whole scenario (break, fix, cleanup) on that platform. The build machine tested **kind only** (3 nodes and 1 node, on macOS arm64); every other cell is still to be ticked by an instructor.

| Scenario | kind | minikube | Docker Desktop | Killercoda | iximiuz | WSL2 |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|
| K01 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K02 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K03 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K04 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K05 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K06 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K07 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K08 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K09 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K10 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K11 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K12 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K13 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K14 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| K15 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

**Known platform-sensitive scenarios.** Look at these first:

- **K07 and K11 timing:** K07's app takes about 20 seconds to wake up and K11's broken release needs a moment to be refused by its readiness check. On a slow or busy node the restarts and the "timed out" moment come a little later than the README says. Wait for the visible symptom before you start explaining.
- **K08 `OOMKilled` vs `Error`:** the kill is the same, but on some clusters and container runtimes the `STATUS` column shows `Error` instead of `OOMKilled`. Check `kubectl describe pod` (the `Last State` shows the reason and exit code 137) before the class.
- **K10 StorageClass names:** `standard` on kind and minikube, `hostpath` on Docker Desktop, `local-path` on Killercoda. A default class must exist. K10 also downloads Kanboard at fix time (and K01, K02 download Excalidraw).
- **K12 and K13 DNS error wording:** the exact message from the failed name lookup (`Name or service not known`, `Temporary failure in name resolution`, ...) differs between images and cluster DNS versions. The idea (the name does not resolve) is the same.
- **K13 enforcement:** needs a NetworkPolicy-enforcing cluster. Run it on your platform before class. If it stops with its "not enforced" message, switch cluster (minikube: `--cni=calico`) or skip K13.

Found a difference? Write it next to the scenario's README commands, so the next instructor knows.

➡️ Back to the [Kubernetes track](../README.md)
