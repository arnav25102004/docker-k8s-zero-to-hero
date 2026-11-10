# Lab K07: ConfigMaps & Secrets: Change Tonight's Poll Without Rebuilding

> ⏱ 45 min · 🟡 Intermediate

## 🎯 What you'll learn
- Separate configuration from the image: same image, different behaviour
- Consume config as **environment variables** and as **files**
- What Kubernetes Secrets are, and what they are **not** (encryption)
- Why editing a ConfigMap doesn't change env vars in running Pods

## 🧠 Concept in 60 seconds
| | ConfigMap | Secret |
|---|---|---|
| For | settings, URLs, feature flags, config files | passwords, tokens, keys, certificates |
| Stored as | plain text in etcd | **base64** in etcd (encoding, *not* encryption) |
| Protection | none | RBAC can restrict reads; encryption at rest can be enabled |

## 🧪 Hands-on

### Step 1: Deploy with config
```bash
kubectl apply -f kubernetes/stack/
kubectl apply -f kubernetes/07-config-secrets/config.yaml
kubectl apply -f kubernetes/07-config-secrets/deployment.yaml
kubectl rollout status deploy/api
kubectl port-forward svc/frontend 8080:80
```
(On a playground such as Killercoda or iximiuz, add `--address 0.0.0.0` so the platform's port link can reach it.)
The page shows **Cats vs Dogs, v1.1.0**, values that came from the ConfigMap.

### Step 2: How the app receives config
```bash
POD=$(kubectl get pod -l app=api -o name | head -1)
kubectl exec $POD -- env | grep -E 'TITLE|VOTE_OPTIONS|THEME|DB_PASSWORD'
kubectl exec $POD -- cat /etc/showdown/features.json
kubectl exec $POD -- ls -l /etc/secrets/
```

### Step 3: 🎤 Change tonight's poll, live
The audience is watching. Swap the entire poll by editing **config only**:
```bash
kubectl patch configmap showdown-config --type merge -p '{"data":{
  "TITLE":"The Great Bengaluru Food Fight",
  "VOTE_OPTIONS":"dosa:🥞:Benne Dosa,biryani:🍛:Biryani,coffee:☕:Filter Coffee,puri:🥙:Masala Puri",
  "THEME_COLOR":"#ffb400",
  "APP_VERSION":"1.2.0"}}'
```
Look at the browser… **nothing changed.** 🤔
```bash
kubectl exec $POD -- env | grep TITLE        # still "Cats vs Dogs"
```
Environment variables are read **once, when the container starts**. You need new Pods:
```bash
kubectl rollout restart deploy/api
```
Now the screen flips to 🥞🍛☕🥙 in yellow, with zero downtime. **Same image. New app.** Let the room vote. 😄

### Step 4: Files update live (env vars don't)
```bash
kubectl patch configmap showdown-config --type merge -p '{"data":{"features.json":"{\"confetti\": false}"}}'
sleep 60       # the kubelet syncs mounted ConfigMaps periodically
POD=$(kubectl get pod -l app=api -o name | head -1)
kubectl exec $POD -- cat /etc/showdown/features.json      # ✅ updated without a restart
```
| Consumed as | Updates in a running Pod? |
|---|---|
| env var (`env`, `envFrom`) | ❌ needs a restart |
| mounted file | ✅ after about a minute (except with `subPath`) |

### Step 5: "Secret" ≠ encrypted 🔓
```bash
kubectl get secret showdown-secret -o yaml
kubectl get secret showdown-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo
```
Anyone with `get secret` permission can read it. Protect Secrets with **RBAC** (K14), and never commit real values to Git.

### Step 6: Imperative shortcuts
```bash
kubectl create configmap demo --from-literal=COLOR=blue --from-literal=SIZE=large --dry-run=client -o yaml
kubectl create secret generic demo --from-literal=password='p@ss' --dry-run=client -o yaml
```

### Step 7: 💥 Missing config = Pod won't start
```bash
kubectl patch deploy api --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/envFrom/-","value":{"configMapRef":{"name":"does-not-exist"}}}]'
sleep 5; kubectl get pods -l app=api        # new Pod: CreateContainerConfigError; old Pods keep serving
kubectl describe pod -l app=api | grep -i -A2 'warning' | head -4
kubectl rollout undo deploy/api
```
[Scenario K09](../scenarios/09-adminer-missing-secret/README.md) shows the same `CreateContainerConfigError` with a missing Secret.

## 🏭 In production
- Don't keep real Secrets in Git as plain YAML. Use **External Secrets Operator** (AWS Secrets Manager, Vault, GCP, Azure), **Sealed Secrets**, or the **Secrets Store CSI driver**.
- Enable **encryption at rest** for etcd.
- Prefer secrets **as files** over env vars: env vars leak into crash dumps and child processes.
- Versioned, immutable ConfigMaps (`showdown-config-v7`, `immutable: true`) make config changes auditable and roll back cleanly. Kustomize generates them for you.

## ✅ Checkpoint
<details><summary>1. You changed a ConfigMap but the app didn't change. Why?</summary>

It's consumed as env vars, which are fixed at container start. Run `kubectl rollout restart`.
</details>
<details><summary>2. Are Secrets encrypted?</summary>

Not by default. They're base64-encoded. Enable encryption at rest and restrict access with RBAC.
</details>

## 🧹 Cleanup
```bash
kubectl delete -f kubernetes/07-config-secrets/ --ignore-not-found
```

➡️ Next: [K08: Health Probes](../08-probes/README.md)
