# Lab K11: Jobs & CronJobs

> ⏱ 30 min · 🟢 Beginner → 🟡 Intermediate

## 🎯 What you'll learn
- Run tasks **to completion** (Job) and **on a schedule** (CronJob)
- Parallelism, retries (`backoffLimit`), deadlines, and cleanup (TTL)
- Debug a failing Job

## 🧠 Concept in 60 seconds
A Deployment keeps Pods **running forever**. A **Job** keeps creating Pods **until N of them succeed**. A **CronJob** creates a Job on a cron schedule.

## 🧪 Hands-on

### Step 1: Run the Jobs and the CronJob
```bash
kubectl apply -f kubernetes/11-jobs-cronjobs/jobs.yaml
kubectl get jobs -w                  # report: 0/5 → 5/5 (two at a time)
```
```bash
kubectl get pods -l job-name=report
kubectl logs -l job-name=report --prefix
```

### Step 2: A failing Job
```bash
kubectl get pods -l job-name=flaky          # 3 Pods (1 + 2 retries), all Error
kubectl describe job flaky | grep -A 5 -E 'Conditions|Events'
kubectl logs -l job-name=flaky --prefix
```
`BackoffLimitExceeded` is the reason. Retries are spaced out with exponential back-off.

### Step 3: CronJob
```bash
kubectl get cronjob heartbeat
sleep 70; kubectl get jobs              # a new heartbeat-<number> Job appears every minute
kubectl logs job/<one-of-the-heartbeat-jobs>
```
Trigger a run manually (great for testing):
```bash
kubectl create job heartbeat-manual --from=cronjob/heartbeat
kubectl logs job/heartbeat-manual
```
Pause it without deleting:
```bash
kubectl patch cronjob heartbeat -p '{"spec":{"suspend":true}}'
```

## 🏭 In production
- Make jobs **idempotent**. They *will* be retried, sometimes run twice, and sometimes start late.
- Set `activeDeadlineSeconds` so a hung job doesn't run forever, and `ttlSecondsAfterFinished` so finished Jobs don't pile up.
- CronJob schedules use the controller's time zone (UTC on most clusters). Use `spec.timeZone: "Asia/Kolkata"` to be explicit.
- Database migrations as a Job (or Helm hook) before a rollout are a very common pattern.

## ✅ Checkpoint
<details><summary>1. Why must Job Pods use <code>restartPolicy: Never</code> or <code>OnFailure</code>?</summary>

`Always` would restart a container that finished successfully, so the Job would never complete.
</details>

## 🔥 Now break it
When a Job gives up:
- [K28](../scenarios/28-leaderboard-reset-job/README.md): the nightly reset that ran three times and quit

## 🧹 Cleanup
```bash
kubectl delete -f kubernetes/11-jobs-cronjobs/jobs.yaml; kubectl delete job heartbeat-manual --ignore-not-found
```

➡️ Next: [K12: Gateway API & Ingress](../12-gateway-ingress/README.md)
