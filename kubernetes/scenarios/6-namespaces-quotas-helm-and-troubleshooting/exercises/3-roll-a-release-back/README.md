# S6.x3 · Roll a release back

*You upgraded the stall and the menu is wrong. Helm remembers every version. Go back to yesterday.*

⏱ about 12 min · intermediate · helm install, upgrade, history, rollback, values

This is a **question exercise**: there is no `break.sh`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
A Helm chart is a package of Kubernetes YAML with blanks (values). A **release** is one install of that chart. Every upgrade creates a new revision, and `helm rollback` returns to an earlier one. It is the "undo" button for the whole application. Needs `helm` on your machine. It uses the chart you met in S6.3.

## 🛠 Set the scene
```bash
CHART=kubernetes/scenarios/6-namespaces-quotas-helm-and-troubleshooting/3-upgrade-that-broke-the-stall/chart/stall
helm install stall $CHART -n ex-6-3 --create-namespace --wait
```

## ❓ Your tasks
1. Run `helm list -n ex-6-3` and `helm history stall -n ex-6-3`. What revision are you on?
2. Upgrade with a new message and more replicas: `helm upgrade stall $CHART -n ex-6-3 --set message="Samosa is sold out" --set replicaCount=4 --wait`. Read the message back: `kubectl get deploy stall -n ex-6-3 -o jsonpath='{.spec.template.spec.containers[0].args[0]}{"\n"}'`.
3. Check `helm history` again. How many revisions? What does `helm get values stall -n ex-6-3` show (only your changes)?
4. Roll back to revision 1: `helm rollback stall 1 -n ex-6-3 --wait`. What is the message and the replica count now? What revision number are you on?

## 💡 Hints
<details><summary>Hint 1</summary>

`--set` overrides only the values you name; everything else keeps the chart's defaults.

</details>

<details><summary>Hint 2</summary>

A rollback is itself a new revision.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. Revision 1, status `deployed`.
2. `-text=Samosa is sold out` and four Pods.
3. Two revisions. `helm get values` prints only `message` and `replicaCount`: your overrides, not the defaults.
4. The original biryani message and two replicas. You are on **revision 3**: Helm never rewrites history, a rollback is recorded as a new revision that copies revision 1.

</details>

## 🧹 Clean up
```bash
helm uninstall stall -n ex-6-3
kubectl delete namespace ex-6-3
```

← [Section 6: Namespaces, quotas, Helm and troubleshooting](../../README.md)
