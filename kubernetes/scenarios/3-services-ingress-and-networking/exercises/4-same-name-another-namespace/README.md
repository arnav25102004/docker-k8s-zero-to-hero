# S3.x4 · Same name, another namespace

*Why does `http://shop` work in one namespace and fail in the next?*

⏱ about 10 min · intermediate · cluster DNS, search domains, namespaces, FQDN

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
Two classes both have a "shop" Service. Each works fine for its own Pods, but a Pod from the other class cannot reach it by the short name. The reason is a tiny file inside every Pod, `/etc/resolv.conf`.

## 🛠 Set the scene
```bash
kubectl create namespace ex-3-4a
kubectl create namespace ex-3-4b
kubectl create deployment shop -n ex-3-4a --image=hashicorp/http-echo:1.0.0 -- /http-echo -text="shop of class A"
kubectl expose deployment shop -n ex-3-4a --port=80 --target-port=5678
kubectl run client -n ex-3-4b --image=busybox:1.36 -- sleep 3600
kubectl wait pod/client -n ex-3-4b --for=condition=Ready --timeout=120s
kubectl rollout status deployment/shop -n ex-3-4a --timeout=120s
```

## ❓ Your tasks
1. From the client in namespace `ex-3-4b`: `kubectl exec client -n ex-3-4b -- wget -qO- -T 3 http://shop`. What happens?
2. Read the search list: `kubectl exec client -n ex-3-4b -- cat /etc/resolv.conf`. Which domains will it try for `shop`?
3. Fix it without changing anything in the cluster: use `http://shop.ex-3-4a`. Then try the full form `http://shop.ex-3-4a.svc.cluster.local`.
4. Why does this make namespaces handy for separating classes or teams?

## 💡 Hints
<details><summary>Hint 1</summary>

A short name is only completed with the client's own namespace.

</details>

<details><summary>Hint 2</summary>

Look at the first line that starts with `search`.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. It fails (the name does not resolve): `shop` is looked up as `shop.ex-3-4b.svc.cluster.local` and no such Service exists there.
2. `search ex-3-4b.svc.cluster.local svc.cluster.local cluster.local`. The client's own namespace comes first.
3. Both work and print `shop of class A`. `shop.ex-3-4a` is `<service>.<namespace>`, the long name is the full address.
4. Each namespace is its own name space: two teams can both have a `shop` or `db` without clashing, and still reach each other deliberately by using the longer name.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-3-4a ex-3-4b
```

← [Section 3: Services, ingress and networking](../../README.md)
