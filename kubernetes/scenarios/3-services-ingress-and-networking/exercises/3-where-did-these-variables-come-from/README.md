# S3.x3 · Where did these variables come from?

*Nobody set REDIS_PORT. It is right there in the environment anyway.*

⏱ about 8 min · intermediate · Service environment variables, Pod start order, DNS as the better way

This is a **question exercise**: there is no `break.sh`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
In the Cats vs Dogs app you may have met a strange `REDIS_PORT=tcp://10.96.0.12:6379`. Nobody wrote it. Kubernetes adds environment variables for every Service that already exists when a Pod starts. It is an old feature, and it has a catch.

## 🛠 Set the scene
```bash
kubectl create namespace ex-3-3
kubectl run early -n ex-3-3 --image=busybox:1.36 -- sleep 3600
kubectl create service clusterip cache -n ex-3-3 --tcp=6379:6379
kubectl run late -n ex-3-3 --image=busybox:1.36 -- sleep 3600
kubectl wait pod/early pod/late -n ex-3-3 --for=condition=Ready --timeout=120s
```

## ❓ Your tasks
1. Compare: `kubectl exec early -n ex-3-3 -- env | grep CACHE` and `kubectl exec late -n ex-3-3 -- env | grep CACHE`. What differs, and why?
2. Read the names of the variables in `late`. How does the Service name `cache` turn into the variable names?
3. Which approach is more reliable for finding the Service: the environment variables or its DNS name? Test: `kubectl exec early -n ex-3-3 -- nslookup cache` (or `wget`/`ping` to `cache`).
4. You can switch the feature off per Pod with `enableServiceLinks: false`. Why might you want that in a namespace with hundreds of Services?

## 💡 Hints
<details><summary>Hint 1</summary>

`early` started before the Service existed.

</details>

<details><summary>Hint 2</summary>

The names are the Service name in capitals, with `-` turned into `_`.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. `early` prints nothing; `late` prints variables such as `CACHE_SERVICE_HOST`, `CACHE_PORT` and `CACHE_PORT_6379_TCP`. The variables are set **only when the Pod starts**, for Services that exist at that moment.
2. `cache` becomes `CACHE_`, followed by `SERVICE_HOST`, `SERVICE_PORT`, `PORT` and so on.
3. DNS. The name `cache` works from any Pod, early or late, and keeps working if the Service is recreated. Environment variables depend on start order.
4. Every Service adds several variables to every Pod. With hundreds of Services that is a lot of noise, and it can even slow Pod start-up.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-3-3
```

← [Section 3: Services, ingress and networking](../../README.md)
