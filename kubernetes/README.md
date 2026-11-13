# ☸️ Track 2: Kubernetes

By the end of this track you can deploy, expose, update, scale, secure, and debug real applications on Kubernetes, and explain *why* each production practice exists.

## ✅ Before you start: five things to set up (about 30 minutes, once)

You cannot master Kubernetes in a few hours, and nobody expects that. The goal is smaller and more useful: after these sessions you are **familiar with every moving part and confident moving around a cluster**. These five tools are what a real engineer has open on day one.

| # | Set up | Why you want it | Time |
|---|---|---|---|
| 1 | [A cluster and `kubectl`](#1-a-cluster-and-kubectl) | nothing works without one | 10 min |
| 2 | [`kubectx` and `kubens`](#2-kubectx-and-kubens-switch-namespaces-without-typing--n) | stop typing `-n <namespace>` all day | 3 min |
| 3 | [metrics-server](#3-metrics-server-who-is-using-what) | see which Pod or node is using how much | 2 min |
| 4 | [Helm](#4-helm-the-package-manager-of-kubernetes) | how real teams install software | 3 min |
| 5 | [Prometheus + Grafana, then Jenkins and Argo CD](#5-real-software-on-your-cluster-prometheus-grafana-jenkins-argo-cd) | see how real applications look inside a cluster | 10 min |

Check what you already have at any time: `./scripts/check-prereqs.sh`

### 1. A cluster and `kubectl`
You need **one working Kubernetes cluster** and the ability to run `kubectl` against it. It does not matter how you got it:

| If you have… | Do this |
|---|---|
| **Docker Desktop** | Settings → Kubernetes → Enable |
| **kind** (recommended: the course config pins a 3-node cluster) | `kind create cluster --name z2h --config 00-setup/kind-cluster.yaml` |
| **minikube** | `minikube start --cpus 4 --memory 6g` |
| **Killercoda** or **iximiuz Labs** | open a Kubernetes playground in the browser; `kubectl` is ready |
| **A cloud cluster** (EKS, GKE, AKS) | works too, but you pay for it, so prefer a local one for these labs |

Full steps for each are in [00-setup](../00-setup/README.md). Then check:
```bash
kubectl version
kubectl get nodes                  # every node should say Ready
kubectl config current-context     # which cluster you are talking to
```
> ℹ️ **Honest note:** the labs and scenarios are tested on **kind**. The others should work, and the [scenario guide](scenarios/README.md) lists the known differences, but kind is the one with a passing test run behind it.

### 2. `kubectx` and `kubens`: switch namespaces without typing `-n`
Every scenario lives in its own namespace (`k-08-oomkilled`, `k-25-hpa`, …). Typing `-n k-08-oomkilled` on every command is slow and easy to get wrong. **kubens** sets your *current* namespace once, then plain `kubectl get pods` works. **kubectx** does the same for clusters (contexts).

Install:
```bash
# macOS (Homebrew), installs both
brew install kubectx

# Ubuntu / Debian
sudo apt install kubectx          # or: sudo snap install kubectx --classic

# Windows (Chocolatey or Scoop)
choco install kubens kubectx
scoop install kubectx kubens

# Any Linux, no package manager
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
```
Use it:
```bash
kubens                       # list namespaces (arrow keys to pick, if you also install fzf)
kubens k-08-oomkilled        # from now on, kubectl works in this namespace
kubectl get pods             # no -n needed
kubens -                     # jump back to the previous namespace
kubens default               # back home
kubectx                      # the same idea for clusters
```
> ⚠️ **Habit to build:** `kubens` changes your kubeconfig, and scenario cleanup deletes the namespace but not your setting. After a cleanup, run `kubens default`, or `kubectl get pods` will answer *"No resources found"* from a namespace that no longer exists. (That exact confusion is scenario K38.)

The commands in the labs and scenarios always spell out `-n`, so they work with or without kubens. It is your shortcut, not a requirement.

### 3. metrics-server: who is using what?
Without it, `kubectl top` fails and the autoscaler has nothing to read. You are flying without instruments: you cannot tell which node, Pod or namespace is eating the CPU and memory.
```bash
./scripts/install-metrics-server.sh
kubectl top nodes
kubectl top pods -A --sort-by=memory | head
```
It installs the pinned release, waits about a minute for the first numbers, and does nothing if it is already there. Lab [K01](01-cluster-tour/README.md) uses it in the tour and lab [K13](13-autoscaling/README.md) builds on it.

### 4. Helm: the package manager of Kubernetes
Real teams do not write hundreds of lines of YAML for every tool. They install a **chart** (a package) with one command and change its **values** (settings). Install Helm 3.8 or newer (Helm 4 works too):
```bash
# macOS
brew install helm
# Windows
winget install Helm.Helm            # or: choco install kubernetes-helm
# Linux
sudo snap install helm --classic    # or follow https://helm.sh/docs/intro/install/
```
Check:
```bash
helm version
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo kube-prometheus-stack
```
Lab [K19](19-observability/README.md) teaches Helm properly (install, upgrade, rollback, values). For now, you only need it to run.

### 5. Real software on your cluster: Prometheus, Grafana, Jenkins, Argo CD
The core labs use small demo apps. In a real job you will meet *big* ones, and the fastest way to feel what a real cluster looks like is to install a few. **Install one at a time and remove it before the next** (each needs about 1 to 2 GB of memory). All of these use `kubectl port-forward`, so they work on every cluster.

**a) Prometheus + Grafana (monitoring).** The one you will keep.
```bash
./scripts/install-monitoring.sh                       # about 5 minutes the first time
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```
Open http://localhost:3000 (login `admin` / `z2h-grafana`). Lab [K19](19-observability/README.md) walks through it, and many scenarios have a "👀 See it in monitoring" tip that uses it.

**b) Jenkins (the CI server half the industry runs).**
```bash
helm repo add jenkins https://charts.jenkins.io && helm repo update
helm install jenkins jenkins/jenkins --version 5.11.0 -n jenkins --create-namespace \
  --set persistence.enabled=false --wait --timeout 10m
kubectl get secret -n jenkins jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode; echo
kubectl port-forward -n jenkins svc/jenkins 8081:8080
```
Open http://localhost:8081, user `admin`, the password printed above. The first start downloads plugins, so give it a few minutes.

**c) Argo CD (GitOps: the cluster that deploys itself from Git).**
```bash
helm repo add argo https://argoproj.github.io/argo-helm && helm repo update
helm install argocd argo/argo-cd --version 10.17.0 -n argocd --create-namespace --wait --timeout 10m
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl port-forward -n argocd svc/argocd-server 8080:443
```
Open https://localhost:8080 (accept the self-signed certificate), user `admin`. If Helm says a version is not found, list what exists with `helm search repo argo/argo-cd --versions | head` and use the newest one.

**What to look at (this is the point).** After each install, open the cluster the way you learned and connect the dots:
```bash
kubectl get all -n jenkins                     # Deployments, Pods, Services: Labs K04 and K05
kubectl get pvc,configmap,secret,sa -n jenkins # storage, config, identity: Labs K07, K10, K14
helm get manifest jenkins -n jenkins | grep '^kind:' | sort | uniq -c
kubectl top pods -n jenkins                    # metrics-server at work
```
That last command counts every kind of object one `helm install` created. You will recognise nearly all of them from the labs. That is the moment the course clicks: the "big" tools are the same small pieces, assembled.

Remove each one when you are done:
```bash
helm uninstall jenkins -n jenkins && kubectl delete namespace jenkins
helm uninstall argocd -n argocd && kubectl delete namespace argocd
./scripts/uninstall-monitoring.sh
```

**Want to see it all as a picture?** The optional [Kubilitics](https://kubilitics.com/) desktop app draws your cluster live: [K01, Step 9](01-cluster-tour/README.md).

| # | Lab | Time | Level |
|---|---|---|---|
| **K00** ⭐ | [**Kubernetes Foundations**: why orchestration, how Kubernetes thinks](00-foundations/README.md) · [quiz](00-foundations/quiz.md) | 2.5–3h | 🟢 |
| K01 | [Tour of a Cluster](01-cluster-tour/README.md) | 50m | 🟢 |
| K02 | [Pods](02-pods/README.md) | 50m | 🟢 |
| K03 | [Namespaces, Labels & Selectors](03-namespaces-labels/README.md) | 30m | 🟢 |
| K04 | [Deployments: Self-Healing You Can See](04-deployments/README.md) | 45m | 🟢 |
| K05 | [Services & DNS](05-services/README.md) | 50m | 🟢→🟡 |
| K06 | [Rolling Updates: "One More Thing…"](06-rollouts/README.md) | 50m | 🟡 |
| K07 | [ConfigMaps & Secrets](07-config-secrets/README.md) | 45m | 🟡 |
| K08 | [Health Probes](08-probes/README.md) | 50m | 🟡 |
| K09 | [Resources, QoS & Quotas](09-resources-qos/README.md) | 50m | 🟡 |
| K10 | [Storage & StatefulSets](10-storage-statefulsets/README.md) | 50m | 🟡 |
| K11 | [Jobs & CronJobs](11-jobs-cronjobs/README.md) | 30m | 🟢→🟡 |
| K12 | [Gateway API & Canary Releases](12-gateway-ingress/README.md) | 60m | 🟡→🔴 |
| K13 | [Autoscaling](13-autoscaling/README.md) | 40m | 🟡 |
| K14 | [RBAC & ServiceAccounts](14-rbac/README.md) | 40m | 🟡 |
| K15 | [Network Policies](15-network-policies/README.md) | 40m | 🟡→🔴 |
| K16 | [Pod Security](16-pod-security/README.md) | 40m | 🟡→🔴 |
| K17 | [Scheduling & Availability](17-scheduling/README.md) | 60m | 🔴 |
| K18 | [🏆 Capstone: The Showdown Goes to Production](18-capstone/README.md) | 2h | 🔴 |
| K19 | [🔔 Bonus: See Everything: Helm, Prometheus & Grafana](19-observability/README.md) (after K13; many scenarios link to it) | 60m | 🟡 |
| 🔥 | [Break-and-fix scenarios K01 … K45](scenarios/README.md) (separate from the labs above) | ~8h | 🟢→🔴 |

## How the labs and the scenarios fit together
| You want to… | Go to |
|---|---|
| **Learn** a topic from zero | the lab (K00–K19), in order |
| **Practise** it by fixing something broken | the matching scenarios: each lab ends with a "🔥 Now break it" list |
| **Get fast at debugging** | the [scenarios](scenarios/README.md) on their own: every scenario has a diagram, a prediction step, a hint ladder, and a `./check.sh` |

Lab numbers (K00–K19) and scenario numbers (K01–K45) are two separate lists that happen to share a prefix. Scenario links always say `scenarios/`.

Every lab opens its concept with a diagram and gives you a 🏆 challenge to solve before the quiz. To check that the lab manifests still work on your cluster: `./tests/labs/validate-labs.sh` (throwaway cluster only; it starts no Pods).

[`stack/`](stack/README.md) holds the shared frontend + Redis manifests used by K04–K13.

**The story arc:** K04: votes jump between Pods → K05: shared Redis fixes it → K06: ship v2 🦄 mid-vote with 0 failures → K07: swap the whole poll via config → K12: canary 10% of traffic → K13: the Pod wall grows by itself → K18: survive the Gauntlet.
