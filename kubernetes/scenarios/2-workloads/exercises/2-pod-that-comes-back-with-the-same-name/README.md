# S2.x2 · The Pod that comes back with the same name

*Delete a Deployment Pod and you get a stranger. Delete a StatefulSet Pod and your old friend returns.*

⏱ about 12 min · intermediate · StatefulSet, stable Pod names, headless Service, ordered start and stop

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
Some programs, like databases, need to know who they are: "I am number 1, my friend is number 0". A Deployment gives Pods random names. A StatefulSet gives them fixed ones (`name-0`, `name-1`, ...), starts them in order, and brings a deleted one back under the same name.

## 🛠 Set the scene
```bash
kubectl create namespace ex-2-2
kubectl apply -n ex-2-2 -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  clusterIP: None
  selector: { app: echo }
  ports:
    - port: 5678
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: echo
spec:
  serviceName: echo
  replicas: 3
  selector:
    matchLabels: { app: echo }
  template:
    metadata:
      labels: { app: echo }
    spec:
      terminationGracePeriodSeconds: 1
      containers:
        - name: echo
          image: hashicorp/http-echo:1.0.0
          args: ["-text=hello from the stall"]
          readinessProbe:
            httpGet: { path: /, port: 5678 }
            periodSeconds: 2
EOF
kubectl get pods -n ex-2-2 -w
```

## ❓ Your tasks
1. Watch the Pods appear (Ctrl+C when all three run). In what order did they start, and what are they called?
2. Note the IP of `echo-1` (`kubectl get pod echo-1 -n ex-2-2 -o wide`), then delete it. What is the new Pod called? Did the IP change?
3. Reach one Pod by its stable name from inside the cluster: `kubectl run tmp -n ex-2-2 --rm -it --restart=Never --image=busybox:1.36 -- wget -qO- http://echo-0.echo:5678`
4. Scale down to one replica: `kubectl scale statefulset echo -n ex-2-2 --replicas=1`. Which Pods go first?

## 💡 Hints
<details><summary>Hint 1</summary>

A headless Service (`clusterIP: None`) gives each Pod its own DNS name: `<pod>.<service>`.

</details>

<details><summary>Hint 2</summary>

The ordinal in the name is part of the Pod's identity.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. `echo-0` first, then `echo-1`, then `echo-2`. Each one waits until the previous one is Ready.
2. The new Pod is called `echo-1` again. The IP usually changes: the **name** is stable, the IP is not, which is why you use the DNS name.
3. It prints `hello from the stall`. `echo-0.echo` works because the headless Service creates one DNS record per Pod.
4. Highest number first: `echo-2`, then `echo-1`. Scale-down runs in reverse, so `echo-0` (often the "primary") goes last.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-2-2
```

← [Section 2: Workloads](../../README.md)
