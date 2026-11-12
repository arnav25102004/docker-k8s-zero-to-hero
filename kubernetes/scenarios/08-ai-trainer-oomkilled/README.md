# K08 · No error, no goodbye (Kubernetes edition)

*Your AI model was training. Then it vanished. No error. No goodbye. And Kubernetes keeps bringing it back to die again.*

⏱ 10 min · beginner · an "AI trainer" script (`python:3.12-alpine`, about 19 MB) · memory requests and limits, OOMKilled, exit code 137

⬇️ First run downloads about 19 MB (Python). A slow first download is normal: do it on good Wi-Fi, before the session.

Output columns and wording can differ a little between kubectl, container runtimes and clusters (kind, minikube, Docker Desktop, playgrounds). The ideas never change.

## 📖 The story
It's exam week at Christ University and Meera's final-year project is a "model" that learns from a big dataset. She deploys the training to the lab's Kubernetes cluster and goes for a filter coffee. When she comes back, the training never finishes: the Pod keeps restarting, and each time the output stops at epoch 3 of 6. No red error, no traceback, nothing. Her teammate says, *"Maybe Python crashed?"* Python did not crash. Someone else ended it. This is the Docker story from [D06](../../../docker/scenarios/06-ai-trainer-oom-killed/README.md), and this time Kubernetes tells you who.

## 🧠 The concept: why, what, how
A cluster node's memory is shared by many Pods. To stop one greedy container from eating the whole machine, Kubernetes lets you set a **memory limit** on it. Under the hood it is a Linux **cgroup**: a fence the kernel builds around the container's processes.

Think of a hostel mess with one plate per student. Take more than one plate and the warden quietly takes your tray away. He doesn't write you a letter.

- A **request** (`requests.memory`) is what the scheduler reserves for you when it picks a node.
- A **limit** (`limits.memory`) is the fence. Inside it the program keeps asking for memory and gets it, until the fence is full.
- Then the kernel's **OOM killer** (OOM = Out Of Memory) ends the process with `SIGKILL` (signal 9). A SIGKILL cannot be caught, so the program never prints an error. The exit code is **137 = 128 + 9**.
- Kubernetes notes it as `OOMKilled` and the **kubelet** (the node's agent; the Pod's `restartPolicy` is `Always`) **restarts** the container, which gets killed again, and again (`CrashLoopBackOff`).

```
 epoch 1 ──▶ epoch 2 ──▶ epoch 3 ──▶ 💥 memory over the 64Mi fence ──▶ SIGKILL (137)
                                      ▲                                     │
                                      └──────── Kubernetes restarts it ◀────┘
```

## 🏢 Where you'll meet this at work
- **A Java service whose heap is bigger than the Pod's limit:** it runs fine on a laptop and dies in production (developer, SRE).
- **ML and data jobs on a growing file:** the nightly batch loads a file that grew this month (data engineer, ML engineer).
- **A "right-sizing" review:** a platform team sets limits from measured peak usage (`kubectl top`, Prometheus) and alerts on `OOMKilled` events.

## 💥 Break it
```bash
cd break && ./break.sh
```
What the room should see: the script says the trainer was deployed, but the training never finishes. The Pod keeps restarting and its `RESTARTS` count keeps climbing. There is **no web page and no port to open** in this scenario (it isn't a web app), so everything we do, finding the problem and checking the fix, happens in the terminal with `logs` and `describe`.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. What is the Pod doing?** Watch it for a minute: this is the symptom.
```bash
kubectl get pods -n k-08-oomkilled -w
```
```
NAME                       READY   STATUS             RESTARTS      AGE
trainer-85967484bf-nvtmh   1/1     Running            1 (3s ago)    6s
trainer-85967484bf-nvtmh   0/1     OOMKilled          1 (4s ago)    7s
trainer-85967484bf-nvtmh   0/1     CrashLoopBackOff   1 (14s ago)   20s
trainer-85967484bf-nvtmh   1/1     Running            2 (15s ago)   21s
trainer-85967484bf-nvtmh   0/1     OOMKilled          2 (17s ago)   23s
trainer-85967484bf-nvtmh   0/1     CrashLoopBackOff   2 (14s ago)   36s
trainer-85967484bf-nvtmh   1/1     Running            3 (25s ago)   47s
trainer-85967484bf-nvtmh   0/1     OOMKilled          3 (28s ago)   50s
```
(Shortened: this is what you see if you start watching a few seconds after `break.sh`, and it keeps going. Ages and Pod names will differ, and `-w` prints a new line on every change. Press Ctrl+C when you've seen enough.) The Pod lives only about 2 seconds each time, `RESTARTS` climbs, and the waits between restarts grow (`CrashLoopBackOff`, as in [K03](../03-showdown-crashloop/README.md)). Nobody typed `kubectl delete`. On some clusters the `STATUS` word is `Error` instead of `OOMKilled`: it is the same kill.

<details><summary>💡 Hint</summary>
A container that dies by itself usually leaves an error behind. This one left nothing. What could have ended it silently, without a word? And what does Kubernetes know about how much memory this container is allowed to use?
</details>

**2. Who ended it?** `describe` records the last state of the container that died.
```bash
kubectl describe pod -n k-08-oomkilled -l app=trainer | grep -A4 'Last State'
```
```
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Sun, 08 Nov 2026 09:58:50 +0530
      Finished:     Sun, 08 Nov 2026 09:58:52 +0530
```
(Times will differ.) There is the answer in Kubernetes' own words: `Reason: OOMKilled`, `Exit Code: 137`. The container ran for only 2 seconds (`Started` to `Finished`). On a few setups the reason is shown as `Error` instead of `OOMKilled` (a runtime race on some setups); the exit code **137** is the constant clue.

**3. What did the program say before it died?** Read the last words of the container that was killed.
```bash
kubectl logs -n k-08-oomkilled -l app=trainer --previous
```
```
epoch 1/6 ... loading 25 MB
epoch 2/6 ... loading 25 MB
epoch 3/6 ... loading 25 MB
```
The log stops in the middle of epoch 3, with no error message. A program that crashed on its own would usually say something. This one never got the chance. (If you see `unable to retrieve container logs`, you caught the Pod in the gap between two restarts: wait a few seconds and run it again.)

**4. What fence did we give it?** Look at the memory settings in the Deployment.
```bash
kubectl get deploy trainer -n k-08-oomkilled -o yaml | grep -A4 ' resources:'
```
```
        resources:
          limits:
            memory: 64Mi
          requests:
            memory: 64Mi
```
The limit is **64Mi** (about 67 MB). Does the program need more than that? Each epoch loads 25 MB, six epochs: 150 MB.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The training needs about **150 MB** (6 epochs x 25 MB, plus about 10 MB for Python itself); the container's memory limit is **64Mi** (about 67 MB). When epoch 3 pushed memory past the fence, the kernel's OOM killer sent SIGKILL. Python never saw it coming, so there was no error in the logs. Kubernetes recorded `OOMKilled`, exit code 137, and the kubelet restarted the container, which hit the same wall at the same place.

Calibration (roughly, from about 10 MB for a bare Python 3.12 process plus 25 MB per epoch): after epoch 2 it holds about 60 MB, which still fits; epoch 3 needs about 85 MB and cannot. Allocation (150 MB) minus limit (about 67 MB) leaves a big overshoot, so the kill is certain, and the log ended at epoch 3 in every one of 5 consecutive runs of `break.sh` on the test cluster (kind), and on every restart.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
The script waits for the new Pod and for the training to finish (about 10 seconds). What changed: only the memory settings. Compare the two files:
```bash
diff ../break/app.yaml app.yaml
```
```
33,34c33,34
<             requests: { memory: 64Mi }
<             limits: { memory: 64Mi }
---
>             requests: { memory: 200Mi }
>             limits: { memory: 256Mi }
```
The limit goes from 64Mi to **256Mi**: the real need (150 MB of data + about 10 MB for Python) plus headroom. The request is raised to 200Mi so the scheduler reserves what the program really uses. When the model is finished the script simply waits (`sleep`), so the Pod stays `Running` instead of exiting and being restarted.

By hand (this replaces `./fix.sh`, so you don't need to run both): apply the fixed file from the `fix` folder.
```bash
kubectl apply -f app.yaml
```
Kubernetes starts a new Pod with the bigger limit and removes the old one. Wait about 10 seconds before you start verifying.

## ✅ Verify it yourself
There is no web page to open, so we read the proof. Is the Pod up and stable?
```bash
kubectl get pods -n k-08-oomkilled
```
```
NAME                       READY   STATUS    RESTARTS   AGE
trainer-79f66877c4-xsgxf   1/1     Running   0          7s
```
(The age and Pod name will differ.) One Pod, `1/1` Ready, `0` restarts, and it stays that way. Did the training finish?
```bash
kubectl logs -n k-08-oomkilled -l app=trainer
```
```
epoch 1/6 ... loading 25 MB
epoch 2/6 ... loading 25 MB
epoch 3/6 ... loading 25 MB
epoch 4/6 ... loading 25 MB
epoch 5/6 ... loading 25 MB
epoch 6/6 ... loading 25 MB
✅ model trained
```
Past epoch 3 and all the way to `model trained`. And the new limit is in place:
```bash
kubectl get deploy trainer -n k-08-oomkilled -o yaml | grep -A4 ' resources:'
```
```
        resources:
          limits:
            memory: 256Mi
          requests:
            memory: 200Mi
```
Finally, `describe` has no `Last State` any more (nothing was killed) and the restart count is 0:
```bash
kubectl describe pod -n k-08-oomkilled -l app=trainer | grep -E 'State:|Restart Count'
```
```
    State:          Running
    Restart Count:  0
```

## 🎯 Key takeaways
- A memory **limit** is a hard fence (a cgroup). Go over it and the kernel kills the process, with no warning to the program.
- Exit code **137 = 128 + 9 = SIGKILL**. `Reason: OOMKilled` in `kubectl describe` names the culprit (on some setups it shows as `Error`, still 137).
- The logs of an OOM kill just *stop*. Absence of an error is itself the clue.
- Debug path: `get pods` (OOMKilled / CrashLoopBackOff) → `describe` (Last State, 137) → `logs --previous` (stops mid-epoch) → the limit in the Deployment.
- Set limits from measured usage plus headroom (`kubectl top`, Prometheus), and alert on OOM kills.

## 💎 Lifelong lesson
> Exit 137 means someone killed it. In Kubernetes, `describe` tells you who.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
[K09](../09-adminer-missing-secret/README.md): The database tool won't even start. No logs. Nothing.
