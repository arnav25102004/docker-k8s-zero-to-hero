# 00: Setup: Get Ready in 15 Minutes

Pick **one** option. Everything in this course works on all of them.

| Option | Best for | Docker labs | Kubernetes labs | Multi-node (K17) |
|---|---|---|---|---|
| **A. Docker Desktop** | Windows/macOS laptops, easiest | ✅ | ✅ (enable Kubernetes) | ➖ (kind mode: ✅) |
| **B. Docker + kind** | Linux or macOS, power users | ✅ | ✅ | ✅ |
| **C. minikube** | if you already use it | ✅ | ✅ | ✅ (`--nodes 2`) |
| **D. Killercoda** | no install, any browser, locked-down laptops | ✅ (Ubuntu playground) | ✅ (Kubernetes playground) | ✅ |

**Recommended laptop:** 4 CPUs, 8 GB RAM, 20 GB free disk.

---

## Step 0: Git (needed for everything, and the whole of Track 0)
```bash
git --version          # anything 2.30 or newer is fine
```
Not installed? **macOS:** `xcode-select --install` (or `brew install git`) · **Ubuntu/Debian:** `sudo apt install git` · **Windows:** [git-scm.com](https://git-scm.com/download/win) (includes Git Bash) · **Killercoda:** preinstalled.
Track 0 (Git) needs nothing else. Docker and Kubernetes come in Tracks 1 and 2.

## Option A: Docker Desktop (recommended for beginners)
1. Install Docker Desktop: https://www.docker.com/products/docker-desktop/
2. Start it and wait for the whale icon to show **running**.
3. **Settings → Resources:** give it at least **4 CPUs and 6 GB memory**.
4. **Settings → Kubernetes → Enable Kubernetes → Apply & restart.**
   - Docker Desktop offers two provisioners: **kubeadm** (single node) and **kind** (can be multi-node). Either works.
5. Verify:
```bash
docker version
kubectl config use-context docker-desktop
kubectl get nodes
```

## Option B: Docker + kind
Install Docker (Desktop, or Docker Engine on Linux), `kubectl`, and [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation):
```bash
# macOS
brew install kind kubectl
# Linux (amd64)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && chmod +x kind && sudo mv kind /usr/local/bin/
```
Create the course cluster (1 control plane + 2 workers, NodePort 30080 mapped to your laptop):
```bash
kind create cluster --name z2h --config 00-setup/kind-cluster.yaml
kubectl get nodes
```
Delete it when you're done: `kind delete cluster --name z2h`

> **If `kubectl get nodes` never shows the nodes as Ready (or `kind create cluster` fails with a kubelet error).** The course pins Kubernetes **v1.37**, and the v1.37 kubelet refuses to start on a host that uses **cgroup v1**. Check yours:
> ```bash
> docker info --format '{{.CgroupVersion}}'     # 2 is fine; 1 means an older Linux setup
> ```
> Recent Docker Desktop (macOS, Windows/WSL2) and current Linux distributions use cgroup v2 and need nothing. If you see `1`, either switch the host to cgroup v2 or run the course on an older Kubernetes: replace `kindest/node:v1.37.0` with `kindest/node:v1.34.8` in `00-setup/kind-cluster.yaml` (three lines), then create the cluster again. The labs behave the same.

## Option C: minikube
```bash
minikube start --cpus 4 --memory 6g
# for the multi-node lab (K17) and NetworkPolicy enforcement (K15):
minikube start -p z2h --nodes 2 --cni calico --cpus 2 --memory 4g
```

## Option D: Killercoda (zero install)
1. Go to https://killercoda.com/playgrounds and sign in (free).
2. **Kubernetes labs:** open the **Kubernetes** playground (2 nodes, kubectl ready).
   **Docker labs:** open the **Ubuntu** playground (Docker preinstalled).
3. In the terminal:
```bash
git clone https://github.com/vellankikoti/docker-k8s-zero-to-hero.git
cd docker-k8s-zero-to-hero
```
4. To open a web page (port-forward, NodePort), use the top-right menu **Traffic / Ports** and enter the port number.

**Getting the course image onto Killercoda Kubernetes nodes.** The nodes run containerd, not Docker. Build with whatever is available and import, **on each node** (`ssh node01` for the worker):
```bash
# if docker exists on the node:
docker build -t z2h/api:1.0 apps/api && ./scripts/load-image.sh z2h/api:1.0
```
If no builder is available, push the image from your laptop to a registry the cluster can pull from (Lab D10), then change `image:` in the manifests, or run the Docker labs in the Ubuntu playground and the Kubernetes labs with public images only. ⏳ Killercoda sessions expire after about 1 hour (longer on paid plans): save your work in Git.

---

## ✅ Final check: run this before class
```bash
./scripts/check-prereqs.sh
```
It checks Docker, kubectl, the cluster, free resources, and pre-pulls every image the course uses, so nothing has to download over conference Wi-Fi. 📶

Then build the course images (used in almost every lab):
```bash
docker build -t z2h/api:1.0 apps/api
docker build -t z2h/frontend:1.0 apps/frontend
./scripts/load-image.sh z2h/api:1.0 z2h/frontend:1.0
```

## 🆘 Common setup problems
| Symptom | Fix |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop isn't running. Start it and wait. |
| `kubectl: connection refused` / `localhost:8080` | No cluster or wrong context: `kubectl config get-contexts` |
| Pods `ErrImageNeverPull` / `ImagePullBackOff` for `z2h/api` | The image isn't on the cluster nodes: `./scripts/load-image.sh z2h/api:1.0` |
| `port is already allocated` | Something else uses that port: pick another (`-p 8081:8080`) |
| Apple Silicon: `platform (linux/amd64) does not match` | Only a warning for Intel-only images; Docker emulates them |
| Very slow first run | It's downloading images. Run `./scripts/check-prereqs.sh --pull` beforehand |
