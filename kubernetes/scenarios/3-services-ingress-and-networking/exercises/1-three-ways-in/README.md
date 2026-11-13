# S3.x1 · Three ways into one Service

*The stall is open. Now how do you actually reach it: from a Pod, from your laptop, from outside?*

⏱ about 10 min · beginner · ClusterIP, port-forward, NodePort, port vs targetPort

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
A Service gives a stable address to a changing set of Pods. But "stable address" can mean three different things depending on who is asking. From another Pod, use the ClusterIP and its DNS name. From your laptop, `kubectl port-forward` is the quickest. And to open it to the outside world, the Service type changes.

## 🛠 Set the scene
```bash
kubectl create namespace ex-3-1
kubectl create deployment shop -n ex-3-1 --image=hashicorp/http-echo:1.0.0 -- /http-echo -text="shop is open"
kubectl expose deployment shop -n ex-3-1 --port=80 --target-port=5678
kubectl rollout status deployment/shop -n ex-3-1 --timeout=120s
```

## ❓ Your tasks
1. From inside the cluster: `kubectl run tmp -n ex-3-1 --rm -it --restart=Never --image=busybox:1.36 -- wget -qO- http://shop`. Which of the two numbers in `--port=80 --target-port=5678` did you use?
2. From your laptop: run `kubectl port-forward -n ex-3-1 svc/shop 8080:80` in one terminal, `curl localhost:8080` in another. Stop it with Ctrl+C.
3. Change the type: `kubectl patch svc shop -n ex-3-1 -p '{"spec":{"type":"NodePort"}}'`. Read the new port in the PORT(S) column (like `80:3xxxx/TCP`).
4. Which of the three ways works on every platform (kind, minikube, Docker Desktop, a playground) without extra setup?

## 💡 Hints
<details><summary>Hint 1</summary>

`port` is what clients of the Service use. `targetPort` is where the container really listens.

</details>

<details><summary>Hint 2</summary>

NodePort opens the same high port on every node. Reaching a node from outside depends on where the cluster runs.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. `80`, the Service's `port`. The Service forwards it to `targetPort` 5678, which is where http-echo listens.
2. `curl` prints `shop is open`. Port-forward tunnels through the API server, so it needs no network setup.
3. PORT(S) now shows `80:3xxxx/TCP`. Every node listens on that high port (30000 to 32767) and forwards to the Service.
4. `port-forward`. NodePort needs a route to a node address, which differs on kind (inside Docker), minikube (`minikube service`) and Docker Desktop.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-3-1
```

← [Section 3: Services, ingress and networking](../../README.md)
