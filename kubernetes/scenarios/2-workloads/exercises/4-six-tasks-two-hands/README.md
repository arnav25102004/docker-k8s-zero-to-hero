# S2.x4 · Six tasks, two hands

*A Job with six chores and two helpers: how long should it take, and how do you know it is finished?*

⏱ about 8 min · beginner · Job, completions, parallelism, restartPolicy

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
A Job runs a Pod until it finishes successfully. Ask for `completions: 6` and the Job needs six successful Pods. Add `parallelism: 2` and it runs two at a time. This is how batch work, like resizing 6,000 photos, is spread over a cluster.

## 🛠 Set the scene
```bash
kubectl create namespace ex-2-4
kubectl apply -n ex-2-4 -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: chores
spec:
  completions: 6
  parallelism: 2
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo chore done by $HOSTNAME; sleep 8"]
EOF
kubectl get pods -n ex-2-4 -w
```

## ❓ Your tasks
1. Watch for about half a minute. What is the largest number of Pods `Running` at the same time?
2. How long should the whole Job take, roughly? Check with `kubectl get job chores -n ex-2-4` (COMPLETIONS and DURATION).
3. Read one worker's log: `kubectl logs -n ex-2-4 -l job-name=chores --tail=1 --prefix`
4. Delete the Job, apply it again with `parallelism: 3` (edit the YAML), and predict the new duration before you look.

## 💡 Hints
<details><summary>Hint 1</summary>

Six chores, two at a time, 8 seconds each: that is three rounds.

</details>

<details><summary>Hint 2</summary>

Pods of a finished Job stay as `Completed` so you can read their logs.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. Two. That is `parallelism`.
2. About 24 to 30 seconds: three rounds of two Pods, each round about 8 seconds plus startup. COMPLETIONS ends at `6/6`.
3. Each log line says `chore done by chores-xxxxx`, one per Pod.
4. Three at a time means two rounds, so about half: roughly 16 to 20 seconds.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-2-4
```

← [Section 2: Workloads](../../README.md)
