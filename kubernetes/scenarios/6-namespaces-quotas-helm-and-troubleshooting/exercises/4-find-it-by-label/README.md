# S6.x4 · Find it by label

*A cluster has hundreds of Pods and no search box. Labels are the search box.*

⏱ about 10 min · beginner · labels, selectors (equality and set-based), annotations, kubectl -l

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
Labels are short key/value tags on any object: `app=shop`, `env=prod`. Selectors then find or act on groups of objects: list them, delete them, point a Service at them. **Annotations** are also key/value notes, but they are for humans and tools, and cannot be selected on.

## 🛠 Set the scene
```bash
kubectl create namespace ex-6-4
kubectl run shop-dev    -n ex-6-4 --image=busybox:1.36 --labels=app=shop,env=dev  -- sleep 3600
kubectl run shop-prod-1 -n ex-6-4 --image=busybox:1.36 --labels=app=shop,env=prod -- sleep 3600
kubectl run shop-prod-2 -n ex-6-4 --image=busybox:1.36 --labels=app=shop,env=prod -- sleep 3600
kubectl run desk-dev    -n ex-6-4 --image=busybox:1.36 --labels=app=desk,env=dev  -- sleep 3600
kubectl run desk-prod   -n ex-6-4 --image=busybox:1.36 --labels=app=desk,env=prod,tier=front -- sleep 3600
kubectl get pods -n ex-6-4 --show-labels
```

## ❓ Your tasks
1. List only the production Pods. How many?
2. List Pods where `env` is `dev` **or** `qa`: use the set-based form `-l 'env in (dev,qa)'`.
3. List the production Pods of the shop only (two conditions, comma between them).
4. List the Pods that have **no** `tier` label, then the ones that have one (`-l tier` and `-l '!tier'`).
5. Show `app` and `env` as columns with `-L app,env`. Then add a note: `kubectl annotate pod shop-dev -n ex-6-4 owner="meera@example.com"` and read it back with `kubectl get pod shop-dev -n ex-6-4 -o jsonpath='{.metadata.annotations.owner}{"\n"}'`.
6. Delete every dev Pod in one command.

## 💡 Hints
<details><summary>Hint 1</summary>

A comma between selectors means AND.

</details>

<details><summary>Hint 2</summary>

Quote selectors that contain parentheses or `!`, or your shell will interpret them.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. `kubectl get pods -n ex-6-4 -l env=prod` gives three: `shop-prod-1`, `shop-prod-2`, `desk-prod`.
2. `kubectl get pods -n ex-6-4 -l 'env in (dev,qa)'` gives two (`shop-dev`, `desk-dev`).
3. `-l app=shop,env=prod` gives two.
4. `-l tier` gives `desk-prod`; `-l '!tier'` gives the other four.
5. The `APP` and `ENV` columns appear. The annotation prints the email address. Annotations are stored the same way as labels but you cannot select on them.
6. `kubectl delete pods -n ex-6-4 -l env=dev`.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-6-4
```

← [Section 6: Namespaces, quotas, Helm and troubleshooting](../../README.md)
