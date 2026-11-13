# S1.x4 · Follow a Pod's birth

*One command. Four different components do the work. Can you tell who did which part?*

⏱ about 8 min · beginner · the scheduler, the kubelet and the container runtime, read from Events

This is a **question exercise**: there is no `break.sh`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
You type `kubectl run` and a Pod appears. It feels like one thing happening, but it is a relay race: the API server writes it down, the scheduler picks a node, the kubelet on that node starts it, and the container runtime does the actual work. The cluster keeps a diary of every handover. It is called Events.

## 🛠 Set the scene
```bash
kubectl create namespace ex-1-4
kubectl run hello -n ex-1-4 --image=busybox:1.36 -- sleep 3600
kubectl wait pod/hello -n ex-1-4 --for=condition=Ready --timeout=120s
```

## ❓ Your tasks
1. Print the diary, oldest first: `kubectl get events -n ex-1-4 --sort-by=.lastTimestamp -o custom-columns=REASON:.reason,FROM:.source.component,MESSAGE:.message`. Write down which component reported each line.
2. Which node got the Pod? Find it in the Pod's spec: `kubectl get pod hello -n ex-1-4 -o jsonpath='{.spec.nodeName}{"\n"}'`. Which component wrote that field?
3. Which container runtime ran the container? `kubectl get nodes -o wide` has a column for it.
4. Delete the Pod and run the same command again. Why can the second birth look shorter in Events (no "Pulling" line)?

## 💡 Hints
<details><summary>Hint 1</summary>

The `FROM` column is the answer to task 1. You should see exactly two different names.

</details>

<details><summary>Hint 2</summary>

`spec.nodeName` is empty when a Pod is first created. Someone fills it in later.

</details>

<details><summary>Hint 3</summary>

A line that says "already present on machine" means the image was found on the node.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. `Scheduled` comes from **default-scheduler**. `Pulling`, `Pulled`, `Created` and `Started` come from the **kubelet** on the chosen node. (The kubelet asks the container runtime to do the work; the runtime does not write Events itself.)
2. The Pod is created without a node. The **scheduler** fills in `spec.nodeName`; from then on only the kubelet of that node cares about it.
3. The `CONTAINER-RUNTIME` column, for example `containerd://1.7.x`. That is what pulls the image and starts the process. Docker is not involved on modern clusters.
4. The image is already on the node, so the kubelet skips the download and the event says `Container image "busybox:1.36" already present on machine`.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-1-4
```

← [Section 1: Architecture and Pod lifecycle](../../README.md)
