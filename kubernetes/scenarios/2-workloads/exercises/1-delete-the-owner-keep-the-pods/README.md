# S2.x1 · Delete the owner, keep the Pods

*A ReplicaSet is just a label selector with opinions. Take the opinions away and see what stays.*

⏱ about 10 min · intermediate · ReplicaSet, ownerReferences, selectors, --cascade=orphan

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
Pods do not belong to a Deployment by magic. A ReplicaSet counts the Pods that match its label selector, and creates or deletes until the count is right. Each Pod it creates carries a note saying who owns it (`ownerReferences`). What happens to the Pods if the owner is removed, but the Pods are told to stay?

## 🛠 Set the scene
```bash
kubectl create namespace ex-2-1
kubectl apply -n ex-2-1 -f - <<'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: tea
spec:
  replicas: 3
  selector:
    matchLabels: { app: tea }
  template:
    metadata:
      labels: { app: tea }
    spec:
      terminationGracePeriodSeconds: 1
      containers:
        - name: stall
          image: hashicorp/http-echo:1.0.0
          args: ["-text=tea"]
EOF
until [ "$(kubectl get rs tea -n ex-2-1 -o jsonpath='{.status.readyReplicas}')" = 3 ]; do sleep 2; done
```

## ❓ Your tasks
1. Who owns each Pod? `kubectl get pods -n ex-2-1 -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name`
2. Delete only the ReplicaSet and keep its Pods: `kubectl delete rs tea -n ex-2-1 --cascade=orphan`. What do `kubectl get pods` and the OWNER column show now?
3. Delete one of the orphaned Pods. Does anything create a replacement? Why not?
4. Apply the same ReplicaSet YAML again. How many Pods exist afterwards, and how many were created new?

## 💡 Hints
<details><summary>Hint 1</summary>

Without `--cascade=orphan`, deleting the ReplicaSet deletes its Pods too.

</details>

<details><summary>Hint 2</summary>

A ReplicaSet looks at labels, not at history.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. All three show the ReplicaSet `tea` as owner.
2. The three Pods keep running, and the OWNER column becomes empty (`<none>`). Nobody manages them any more.
3. Nothing replaces it. The Pods have no owner, and there is no ReplicaSet left to count them.
4. You get three Pods in total: the two survivors are **adopted** again because they match the selector `app=tea` and have no owner, so the new ReplicaSet only creates the one that is missing. This is exactly what a Deployment relies on when it takes over Pods during a rollout.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-2-1
```

← [Section 2: Workloads](../../README.md)
