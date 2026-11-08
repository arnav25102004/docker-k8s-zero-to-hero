# Lab K14: RBAC & ServiceAccounts: Who Can Do What

> ⏱ 40 min · 🟡 Intermediate

## 🎯 What you'll learn
- Authentication vs authorisation in Kubernetes
- **Role / ClusterRole** (what) + **RoleBinding / ClusterRoleBinding** (who)
- **ServiceAccounts**: identities for Pods
- Test permissions safely with `kubectl auth can-i`
- Call the Kubernetes API from inside a Pod

## 🧠 Concept in 60 seconds
```
 Subject (User / Group / ServiceAccount) ──RoleBinding──▶ Role { verbs on resources }
                                                         e.g. get,list,watch on pods in ns rbac-lab
```
RBAC is **deny by default** and **additive**: you can only grant permissions, never write a "deny" rule.

| | Scope |
|---|---|
| `Role` + `RoleBinding` | one namespace |
| `ClusterRole` + `ClusterRoleBinding` | whole cluster |
| `ClusterRole` + `RoleBinding` | reuse a common role inside one namespace |

## 🧪 Hands-on

### Step 1: Create the identity and permissions
```bash
kubectl apply -f kubernetes/14-rbac/rbac.yaml
kubectl get sa,role,rolebinding -n rbac-lab
```

### Step 2: Ask the API server "can they?"
```bash
SA=system:serviceaccount:rbac-lab:pod-reader
kubectl auth can-i list pods      -n rbac-lab --as=$SA     # yes
kubectl auth can-i delete pods    -n rbac-lab --as=$SA     # no
kubectl auth can-i list pods      -n default  --as=$SA     # no (Role is namespaced)
kubectl auth can-i get secrets    -n rbac-lab --as=$SA     # no
kubectl auth can-i --list         -n rbac-lab --as=$SA
```
And yourself:
```bash
kubectl auth can-i '*' '*'        # on a local cluster you're probably cluster-admin
```

### Step 3: Use the token from inside a Pod
Every Pod gets its ServiceAccount token mounted automatically:
```bash
kubectl wait -n rbac-lab --for=condition=Ready pod/api-client
kubectl exec -n rbac-lab api-client -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```
Call the API as the ServiceAccount:
```bash
kubectl exec -n rbac-lab api-client -- sh -c '
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  API=https://kubernetes.default.svc
  echo "--- list pods in rbac-lab (allowed):"
  curl -s --cacert $CA -H "Authorization: Bearer $TOKEN" $API/api/v1/namespaces/rbac-lab/pods | grep -m3 "\"name\""
  echo "--- list secrets (forbidden):"
  curl -s --cacert $CA -H "Authorization: Bearer $TOKEN" $API/api/v1/namespaces/rbac-lab/secrets | grep -E "\"(reason|message)\""'
```
🔍 `403 Forbidden` with a clear message: `User "system:serviceaccount:rbac-lab:pod-reader" cannot list resource "secrets"...`. That's exactly what you'll see in logs when an operator or CI job lacks permissions ([scenario K14](../scenarios/14-leaderboard-bot-forbidden/README.md)).

### Step 4: Grant one more permission, the least-privilege way
```bash
kubectl create role read-configmaps -n rbac-lab --verb=get,list --resource=configmaps
kubectl create rolebinding pod-reader-configmaps -n rbac-lab --role=read-configmaps --serviceaccount=rbac-lab:pod-reader
kubectl auth can-i list configmaps -n rbac-lab --as=system:serviceaccount:rbac-lab:pod-reader    # yes
```

### Step 5: Explore built-in ClusterRoles
```bash
kubectl get clusterroles | grep -E '^(admin|edit|view|cluster-admin) '
kubectl describe clusterrole view | head -30
```
Common pattern: `kubectl create rolebinding dev-team-edit -n team-a --clusterrole=edit --group=dev-team`

## 🏭 In production
- **Least privilege.** Give apps only what they call. Most apps need **no** API access at all; set `automountServiceAccountToken: false`.
- Never bind `cluster-admin` to a workload ServiceAccount. A compromised Pod would own the cluster.
- Humans authenticate through the cloud IAM or SSO (OIDC); groups map to Roles. CI/CD gets its own narrowly scoped identity per environment.
- Audit regularly: `kubectl auth can-i --list --as=...`, or tools like `rbac-lookup` and `kubectl-who-can`.

## ✅ Checkpoint
<details><summary>1. A Role allows <code>list pods</code> in namespace A. Can the subject list pods in namespace B?</summary>

No. Roles and RoleBindings are namespaced. You'd need a binding in namespace B, or a ClusterRoleBinding.
</details>
<details><summary>2. How do you write a rule that denies deleting Pods?</summary>

You can't. RBAC has no deny rules. Simply don't grant the `delete` verb. (Admission policies can add restrictions on top.)
</details>

## 🧹 Cleanup
```bash
kubectl delete ns rbac-lab
```

➡️ Next: [K15: Network Policies](../15-network-policies/README.md)
