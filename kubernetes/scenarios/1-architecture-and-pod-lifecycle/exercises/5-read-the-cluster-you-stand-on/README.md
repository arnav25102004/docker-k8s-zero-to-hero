# S1.x5 · Read the cluster you are standing on

*You have been breaking this cluster all day. Do you know what is inside it?*

⏱ about 8 min · beginner · control-plane components, node components, DaemonSets in kube-system, kubelet and runtime versions

This is a **question exercise**: there is no `break.sh`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
Every scenario so far assumed a working cluster. This exercise is a guided tour of that cluster, using only read commands. Nothing is created, so there is nothing to clean up.

## 🛠 Set the scene
```bash
kubectl config current-context
```

## ❓ Your tasks
1. Run `kubectl get nodes -o wide`. Which node has the `control-plane` role? Which kubelet version and which container runtime does each node report?
2. Run `kubectl get pods -n kube-system -o wide`. Put every Pod into one of these boxes: *control plane* (API server, etcd, scheduler, controller manager), *per-node helper* (network, proxy) or *cluster add-on* (DNS).
3. Run `kubectl get daemonset,deployment -n kube-system`. Which of the helpers run as a DaemonSet, and which as a Deployment? Why does that make sense?
4. Ask the API server how it feels: `kubectl get --raw='/readyz?verbose' | head -20`. How many checks are there, and what do they test?
5. On a managed cluster (EKS, GKE, AKS) most of task 2 looks different. What is missing, and why?

## 💡 Hints
<details><summary>Hint 1</summary>

Control plane Pods are named after their component, followed by the node name.

</details>

<details><summary>Hint 2</summary>

Something that must exist on every node is a DaemonSet candidate.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. The node with the `control-plane` role runs the API server and friends. `VERSION` is the kubelet version, `CONTAINER-RUNTIME` is usually `containerd`.
2. Control plane: `kube-apiserver-*`, `etcd-*`, `kube-scheduler-*`, `kube-controller-manager-*`. Per-node helpers: `kube-proxy-*` and the network plug-in (for example `kindnet-*`). Add-on: `coredns-*`.
3. `kube-proxy` and the network plug-in are DaemonSets (one per node, because every node needs them). CoreDNS is a Deployment (a couple of replicas serve the whole cluster).
4. Every line is a health check (`[+]ping`, `[+]etcd`, `[+]poststarthook/...`). `readyz` fails if any one of them fails, which is what a load balancer in front of the API server uses.
5. On a managed cluster the provider runs the control plane for you, so the `kube-apiserver`, `etcd`, scheduler and controller-manager Pods are not visible to you. You only see the node-level helpers and add-ons.

</details>

Nothing to clean up: this exercise only reads.

← [Section 1: Architecture and Pod lifecycle](../../README.md)
