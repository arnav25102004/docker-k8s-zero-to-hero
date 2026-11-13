# S3.x5 · Lock the vault, then give one friend the key

*By default every Pod can talk to every other Pod. Fix that in two short YAML files.*

⏱ about 12 min · advanced · NetworkPolicy, default deny, podSelector, allow rules

This is a **question exercise**: there is no `break.sh`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
A cluster is an open campus: any Pod can call any other Pod. A NetworkPolicy is a gate. The usual recipe is "deny everything into this namespace, then allow only the callers you name". The vault is a web server; the guard is allowed in; the thief is not.

## 🛠 Set the scene
```bash
# Needs a cluster that enforces NetworkPolicy (kind does; Docker Desktop and a plain minikube may not).
kubectl create namespace ex-3-5
kubectl create deployment vault -n ex-3-5 --image=hashicorp/http-echo:1.0.0 -- /http-echo -text="the vault"
kubectl expose deployment vault -n ex-3-5 --port=80 --target-port=5678
kubectl run guard -n ex-3-5 --image=busybox:1.36 --labels=role=guard -- sleep 3600
kubectl run thief -n ex-3-5 --image=busybox:1.36 --labels=role=thief -- sleep 3600
kubectl wait pod/guard pod/thief -n ex-3-5 --for=condition=Ready --timeout=120s
kubectl rollout status deployment/vault -n ex-3-5 --timeout=120s
```

## ❓ Your tasks
1. Before any policy: can both `guard` and `thief` reach the vault? `kubectl exec guard -n ex-3-5 -- wget -qO- -T 3 http://vault`, then the same with `thief`.
2. Lock it: `kubectl apply -n ex-3-5 -f - <<'EOF'` with a policy named `deny-all` that selects every Pod (`podSelector: {}`) and lists `Ingress` under `policyTypes` with no rules. Test both again.
3. Let the guard in: add a second policy `allow-guard` that selects the vault Pods (`app: vault`) and allows ingress `from` Pods labelled `role: guard`. Test both once more.
4. Why did the thief fail without any error message from Kubernetes?

## 💡 Hints
<details><summary>Hint 1</summary>

A policy with no `ingress` rules and `policyTypes: [Ingress]` allows nothing in.

</details>

<details><summary>Hint 2</summary>

Policies add up: traffic is allowed if any policy allows it.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. Both print `the vault`. No policy means everything is allowed.
2. Both now time out (`wget: download timed out`).
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress]
```
3. `guard` works again, `thief` still times out.
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-guard
spec:
  podSelector:
    matchLabels: { app: vault }
  ingress:
    - from:
        - podSelector:
            matchLabels: { role: guard }
```
4. The policy is enforced by the network plug-in, which silently drops the packets. The caller only sees a timeout, which is also why a wrong NetworkPolicy is so hard to spot. (The DNS lookup still works here because the deny is on *ingress* of the vault, not on egress.)

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-3-5
```

← [Section 3: Services, ingress and networking](../../README.md)
