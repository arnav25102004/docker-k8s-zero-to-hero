# S2.x3 · A watchman for chosen gates only

*"One per node" does not have to mean "every node". Tell the DaemonSet where to go.*

⏱ about 8 min · intermediate · DaemonSet, nodeSelector, node labels

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
The college has several gates. Security wants watchmen only at the gates that are open at night. A DaemonSet runs one Pod per node, and a `nodeSelector` narrows that down to nodes carrying a label. Label a node and a watchman appears. Remove the label and he goes home.

## 🛠 Set the scene
```bash
kubectl create namespace ex-2-3
kubectl apply -n ex-2-3 -f - <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: watchman
spec:
  selector:
    matchLabels: { app: watchman }
  template:
    metadata:
      labels: { app: watchman }
    spec:
      terminationGracePeriodSeconds: 1
      nodeSelector:
        z2h-gate: night
      containers:
        - name: watch
          image: busybox:1.36
          command: ["sh", "-c", "echo on duty; sleep 3600"]
EOF
kubectl get daemonset watchman -n ex-2-3
```

## ❓ Your tasks
1. Look at the DESIRED column. Why is it 0?
2. Pick a node: `NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | head -1); NODE=${NODE:-$(kubectl get nodes -o name | head -1)}; echo $NODE` and label it: `kubectl label $NODE z2h-gate=night`. Watch `kubectl get pods -n ex-2-3 -o wide -w`.
3. Remove the label with `kubectl label $NODE z2h-gate-` (note the minus). What happens to the Pod?
4. If you have more than one node: label two. How many watchmen now?

## 💡 Hints
<details><summary>Hint 1</summary>

A DaemonSet asks "which nodes match?" every time a node changes.

</details>

<details><summary>Hint 2</summary>

The trailing `-` after a label name means "remove it".

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. No node has the label `z2h-gate=night`, so the DaemonSet has nothing to place. DESIRED 0 is correct, not broken.
2. The controller notices the new label and a `watchman-xxxxx` Pod starts on that node within seconds.
3. The Pod is deleted again, because the node no longer matches.
4. One watchman per matching node: two labelled nodes, two Pods.

</details>

## 🧹 Clean up
```bash
kubectl label nodes --all z2h-gate-
kubectl delete namespace ex-2-3
```

← [Section 2: Workloads](../../README.md)
