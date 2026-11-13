# S2.x5 · Run the nightly job right now

*It is scheduled for 3 AM. The principal wants the report at 11 AM. You have 5 minutes.*

⏱ about 8 min · intermediate · CronJob, create job --from, suspend, concurrencyPolicy

This is a **question exercise**: there is no `break.sh`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
A CronJob creates a Job on a schedule. Nobody wants to wait until 3 AM to find out whether it works, so Kubernetes lets you fire it by hand, and lets you pause it when something is wrong.

## 🛠 Set the scene
```bash
kubectl create namespace ex-2-5
kubectl apply -n ex-2-5 -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly
spec:
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: report
              image: busybox:1.36
              command: ["sh", "-c", "echo report generated at $(date)"]
EOF
kubectl get cronjob nightly -n ex-2-5
```

## ❓ Your tasks
1. Read the SCHEDULE column. In plain words, when will this run? Has it run yet (see LAST SCHEDULE)?
2. Fire it now: `kubectl create job manual-1 --from=cronjob/nightly -n ex-2-5`, then read its log: `kubectl logs job/manual-1 -n ex-2-5`.
3. Pause the schedule: `kubectl patch cronjob nightly -n ex-2-5 -p '{"spec":{"suspend":true}}'`. What does the SUSPEND column say? Does a manual run still work?
4. What does `concurrencyPolicy: Forbid` change if a run takes longer than the interval?

## 💡 Hints
<details><summary>Hint 1</summary>

The five fields are: minute, hour, day of month, month, day of week.

</details>

<details><summary>Hint 2</summary>

Suspending stops new scheduled runs only.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. `0 3 * * *` is every day at 03:00 (in the controller's time zone, normally UTC). LAST SCHEDULE is `<none>`: it has not fired yet.
2. A Job `manual-1` runs the CronJob's template once and the log prints `report generated at ...`.
3. SUSPEND shows `True`. Scheduled runs stop, but `kubectl create job --from=...` still works because it does not use the schedule.
4. With `Forbid`, a new run is skipped while the previous one is still running. `Allow` (the default) would start overlapping runs, `Replace` would kill the old one.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-2-5
```

← [Section 2: Workloads](../../README.md)
