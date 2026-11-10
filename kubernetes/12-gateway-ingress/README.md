# Lab K12: Gateway API: Canary Releases You Can Watch 🦄

> ⏱ 60 min · 🟡 Intermediate → 🔴 Advanced

## 🎯 What you'll learn
- Why one HTTP entry point beats one LoadBalancer per Service
- **Gateway API**: GatewayClass → Gateway → HTTPRoute (the modern standard)
- **Canary releases**: send 10% of real traffic to a new version, and dial it up
- Header-based routing so testers always get the new version
- How classic **Ingress** relates (you'll still meet it everywhere)

## 🧠 Concept in 60 seconds
```
                       ┌──────────── Gateway (Envoy) ────────────┐
 browsers / phones ──▶ │  HTTPRoute "showdown"                    │
                       │   header x-canary: true ──▶ api-v2 🦄     │
                       │   everything else ── 90% ──▶ api-v1 🐱🐶   │
                       │                   ── 10% ──▶ api-v2 🦄     │
                       └─────────────────────────────────────────┘
```
| Resource | Owned by | Says |
|---|---|---|
| `GatewayClass` | infrastructure | "Envoy Gateway implements gateways of class `eg`" |
| `Gateway` | platform team | "listen on port 80; these namespaces may attach routes" |
| `HTTPRoute` | app team | "send my traffic to my Services, like this" |

> 📰 **Ingress vs Gateway API.** `Ingress` is the original API and is still everywhere. The popular community **ingress-nginx** controller was **retired in March 2026**. Gateway API is the actively developed successor: role-oriented, portable, with weights and header matching built in. Know both; build new things with Gateway API.

## 🧪 Hands-on

### Step 1: Install a Gateway controller (Envoy Gateway)
```bash
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.9.3/install.yaml
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
kubectl get crd | grep gateway.networking.k8s.io          # the Gateway API types now exist
```

### Step 2: Deploy v1 + v2, the Gateway, and the route
Read [`apps.yaml`](apps.yaml), [`gateway.yaml`](gateway.yaml), and [`routes.yaml`](routes.yaml), then:
```bash
kubectl apply -f kubernetes/stack/redis.yaml
kubectl apply -f kubernetes/12-gateway-ingress/apps.yaml
kubectl apply -f kubernetes/12-gateway-ingress/gateway.yaml
kubectl apply -f kubernetes/12-gateway-ingress/routes.yaml
kubectl wait --timeout=2m gateway/shop-gateway --for=condition=Accepted
kubectl get gateway,httproute
```
Envoy Gateway has created a dedicated Envoy proxy for your Gateway. Wait for it:
```bash
kubectl wait -n envoy-gateway-system --for=condition=Ready pod \
  -l gateway.envoyproxy.io/owning-gateway-name=shop-gateway --timeout=2m
```
> On kind/minikube, `PROGRAMMED` stays `False`: there's no cloud load balancer to hand out an address. Routing still works; we port-forward to the proxy.

### Step 3: Open the Gateway
```bash
ENVOY_SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=shop-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl -n envoy-gateway-system port-forward svc/$ENVOY_SVC 8888:80
```
(On a playground such as Killercoda or iximiuz, add `--address 0.0.0.0` so the platform's port link can reach it.)
Open **http://localhost:8888**. *(Docker Desktop also publishes it on `http://localhost` directly: the Service gets `EXTERNAL-IP localhost`.)*

### Step 4: 🦄 Watch the canary
Keep your eyes on the vote cards. Every few seconds the page talks to **v2**, and a **🦄 Unicorns** card (purple theme) flickers in, then disappears again when v1 answers. **That's 10% canary traffic, made visible.** The feed shows `Now talking to version …` each time.

Count it from the terminal:
```bash
for i in $(seq 1 50); do curl -s localhost:8888/api/info | grep -o '"version": "[^"]*"'; done | sort | uniq -c
```
Roughly 45 × `1.0.0` and 5 × `2.0.0-canary`. Votes from both versions land in the same Redis.

### Step 5: 🎚️ Turn up the dial
Confidence is growing. Send half the traffic to v2:
```bash
kubectl patch httproute showdown --type=json -p='[
 {"op":"replace","path":"/spec/rules/1/backendRefs/0/weight","value":50},
 {"op":"replace","path":"/spec/rules/1/backendRefs/1/weight","value":50}]'
```
The unicorns now appear about half the time. Go all in (100% to v2):
```bash
kubectl patch httproute showdown --type=json -p='[
 {"op":"replace","path":"/spec/rules/1/backendRefs/0/weight","value":0},
 {"op":"replace","path":"/spec/rules/1/backendRefs/1/weight","value":100}]'
```
Something went wrong? **Instant rollback**: set the weights back to 100/0. No Pods restart, and nothing is redeployed; it's just routing.

### Step 6: Header-based routing (internal testers)
```bash
curl -s -H 'x-canary: true' localhost:8888/api/info | grep -o '"version": "[^"]*"'
```
Always `2.0.0-canary`. QA tests the new version in production before any real user sees it.

### Step 7: Host-based routing
```bash
curl -s -H 'Host: showdown.local' localhost:8888/api/info | head -c 80; echo     # matches the route
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: other.local' localhost:8888/   # 404: no route for that host
```

### Step 8: Debug a route
```bash
kubectl describe httproute showdown | grep -A 14 'Status:'
```
`Accepted: True` and `ResolvedRefs: True` mean the route attached and all backend Services exist. Break it on purpose (rename `api-v2` to `api-v3` in the route): `ResolvedRefs: False / BackendNotFound`.

### Step 9: Ingress, for reference
Read [`ingress-example.yaml`](ingress-example.yaml): the same host + path → Service idea, but weights and header matches need controller-specific annotations.

## 🏭 In production
- One cloud load balancer → Gateway → hundreds of Services. TLS terminates at the Gateway (HTTPS listener + **cert-manager**).
- **Argo Rollouts** / **Flagger** automate exactly what you did by hand: shift weights step by step, watch error rates, roll back automatically.

## ✅ Checkpoint
<details><summary>1. Why not give every Service <code>type: LoadBalancer</code>?</summary>

Each one is a separate (paid) cloud load balancer and public IP, with no shared TLS, routing, or observability.
</details>
<details><summary>2. How is a Gateway API canary better than "9 v1 Pods + 1 v2 Pod behind one Service"?</summary>

Weights are precise and independent of replica counts, and rollback is a routing change, not a redeploy.
</details>

## 🧹 Cleanup
```bash
kubectl delete -f kubernetes/12-gateway-ingress/routes.yaml -f kubernetes/12-gateway-ingress/gateway.yaml -f kubernetes/12-gateway-ingress/apps.yaml
# Keep Envoy Gateway installed for the capstone (K18), or remove it:
# kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.9.3/install.yaml
```

➡️ Next: [K13: Autoscaling](../13-autoscaling/README.md)
