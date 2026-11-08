# K07 · The impatient guard

*A perfectly healthy app keeps getting killed, every 10 seconds.*

⏱ 10 min · beginner · Cats vs Dogs voting app (`python:3.12-alpine`, about 19 MB) · liveness probe, startup probe, slow starters

⬇️ First run downloads about 19 MB (Python) plus a tiny 4 MB visitor image. A slow first download is normal: do it on good Wi-Fi, before the session.

Output columns and wording can differ a little between kubectl, container runtimes and clusters (kind, minikube, Docker Desktop, playgrounds). The ideas never change.

## 📖 The story
It's the night before the Christ University fest and Ravi deploys the "Cats vs Dogs" poll. The app warms up for about 20 seconds when it starts (it "loads its data"). Priya, being careful, adds a **liveness probe** so Kubernetes will restart the app if it ever hangs. Nice idea. But now the poll never opens: the Pod restarts again and again, and nothing in the logs says "error". The app isn't broken. It is being killed for being slow to wake up.

## 🧠 The concept: why, what, how
Kubernetes has three kinds of health check ("probes"), and each asks a different question:

- **Startup probe:** "Has the app *finished starting*?" Until it passes, the other probes wait.
- **Readiness probe:** "Can it take visitors *right now*?" If not, the Pod is kept out of the Service (see [K06](../06-kanboard-never-ready/README.md)).
- **Liveness probe:** "Is it *still alive*?" If it fails, the kubelet **kills the container and restarts it**.

Think of a guard at a hotel desk. The liveness probe is a guard who knocks on your door and, if you don't answer, breaks it down. Fine for a guest who has fainted, terrible for a guest who is still putting on shoes. A **startup probe** tells the guard: "give this guest a full minute to get dressed before you start knocking."

```
 start ──▶ [ app is warming up: 20 s ] ──▶ listening
              ▲
   liveness knocks at 5 s ... no answer ... KILL ──▶ start again ──▶ knocks at 5 s ... KILL ...
```

## 🏢 Where you'll meet this at work
- **Java / Spring Boot services** that need 30 to 90 seconds to warm up, especially when the node is busy (developer, SRE).
- **Apps that load a big model or cache at boot**, such as an AI service reading a model file into memory (ML engineer, platform team).
- **Database migrations at start-up:** the app runs schema changes before it listens (developer, SRE).

## 💥 Break it
```bash
cd break && ./break.sh
```
What the room should see: the script says the app was deployed, but it never becomes ready. The Pod says `Running` but `0/1`, its `RESTARTS` count keeps climbing, and nobody can vote. A small `visitor` Pod keeps asking the app for `/healthz` every 2 seconds and gets no answer:
```bash
kubectl logs -f visitor -n k-07-slow-start
```
```
❌ 04:09:04 no answer from http://showdown/healthz
❌ 04:09:07 no answer from http://showdown/healthz
❌ 04:09:10 no answer from http://showdown/healthz
```
You can stop it with Ctrl+C. We'll watch it again live when we fix things.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. What is the Pod doing?** Watch it for a minute: this is the symptom.
```bash
kubectl get pods -n k-07-slow-start -w
```
```
NAME                       READY   STATUS    RESTARTS     AGE
showdown-976689b99-b2jrf   0/1     Running   2 (6s ago)   26s
showdown-976689b99-b2jrf   0/1     Running   3 (6s ago)   36s
showdown-976689b99-b2jrf   0/1     CrashLoopBackOff   3 (6s ago)   46s
showdown-976689b99-b2jrf   0/1     CrashLoopBackOff   4 (1s ago)   76s
showdown-976689b99-b2jrf   0/1     Running            5 (52s ago)   2m7s
```
(Shortened; ages and Pod names will differ, and `-w` prints a new line on every change. Press Ctrl+C when you've seen enough.) The Pod is restarted about every 10 seconds at first. After three or four restarts the kubelet starts **backing off**: the waits grow to 10 s, 20 s, 40 s… up to 5 minutes (that is `CrashLoopBackOff`, as in [K03](../03-showdown-crashloop/README.md)), so the cycle gets slower. The pattern is the same, though: `0/1` and a rising `RESTARTS`. Nobody typed `kubectl delete`: something is killing it.

<details><summary>💡 Hint</summary>
Is the app crashing, or is somebody killing it? Which part of Kubernetes is allowed to kill a container, and what rule does it use? Compare the app's start-up time with how long Kubernetes waits before it first checks.
</details>

**2. Who killed it?** `describe` lists the events and the probe settings.
```bash
kubectl describe pod -n k-07-slow-start -l app=showdown | grep -E 'Liveness|Killing|Unhealthy'
```
```
    Liveness:       http-get http://:8080/healthz delay=5s timeout=1s period=5s #success=1 #failure=1
  Warning  Unhealthy  89s (x15 over 2m43s)  kubelet            spec.containers{showdown}: Readiness probe failed: Get "http://10.244.2.82:8080/readyz": dial tcp 10.244.2.82:8080: connect: connection refused
  Warning  Unhealthy  89s (x5 over 2m34s)   kubelet            spec.containers{showdown}: Liveness probe failed: Get "http://10.244.2.82:8080/healthz": dial tcp 10.244.2.82:8080: connect: connection refused
  Normal   Killing    34s (x6 over 2m34s)   kubelet            spec.containers{showdown}: Container showdown failed liveness probe, will be restarted
```
(The IP addresses and counts will differ.) There is the culprit, in the kubelet's own words: `Liveness probe failed` followed by `Container showdown failed liveness probe, will be restarted`. The probe checks `/healthz` after `delay=5s`, then every `period=5s`, and `#failure=1` means one failed check is enough. "Connection refused" means nothing was listening yet.

**3. What was the app doing in those 5 seconds?** Read the last words of the container that was killed.
```bash
kubectl logs -n k-07-slow-start -l app=showdown --previous
```
```
2026-11-08T04:08:42 [showdown-976689b99-b2jrf] simulating slow startup: sleeping 20.0s
2026-11-08T04:08:48 [showdown-976689b99-b2jrf] received signal 15, shutting down gracefully 👋
```
No error, no traceback. The app says it is "simulating slow startup: sleeping 20.0s", and only 6 seconds later it receives signal 15 (SIGTERM, the polite "please stop" from the kubelet). It was killed in the middle of waking up, before it ever listened. (Because the app handled the signal politely, `describe` will show `Exit Code: 0` here, not a crash code. This is not a crash.)

**4. What rule did the kubelet apply?** Look at the probe in the Deployment.
```bash
kubectl get deploy showdown -n k-07-slow-start -o yaml | grep -A8 '^ *livenessProbe:'
```
```
        livenessProbe:
          failureThreshold: 1
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 5
          successThreshold: 1
```
The kubelet starts knocking after 5 seconds, gives up after 1 failure, and the app needs 20 seconds. 5 < 20: it can never win.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The app needs about 20 seconds (`STARTUP_DELAY: "20"`) before it listens on port 8080. The liveness probe starts checking after `initialDelaySeconds: 5`, and `failureThreshold: 1` means the very first refused connection is fatal. So the kubelet kills the container at about 5 to 6 seconds, every time, long before the app is ready. After a few rounds the kubelet adds back-off waits (`CrashLoopBackOff`). The app is healthy; the probe is simply too impatient for a slow starter.
</details>

## 🔧 Fix it
Before you run it, open a **second terminal** and start the live visitor log, so the room sees red turn green:
```bash
kubectl logs -f visitor -n k-07-slow-start
```
Then, in the first terminal:
```bash
cd ../fix && ./fix.sh
```
The script waits for the new Pod, which takes about 25 seconds because the app really does need its 20 seconds to wake up. Then the log flips from ❌ to ✅ lines (Ctrl+C to stop it). The fix keeps the liveness probe exactly as it is and adds a **startupProbe** in front of it. What changed:
```bash
diff ../break/app.yaml app.yaml
```
```
1,2c1
< # K07 break: the app needs about 20 s to wake up, but the liveness probe starts checking after 5 s
< # and gives up after ONE failure, so the app is killed before it is ever ready.
---
> # K07 fix: a startupProbe gives the app up to 60 s (12 x 5 s) to wake up; liveness only starts after it passes.
30a30,35
>           startupProbe:
>             httpGet:
>               path: /healthz
>               port: 8080
>             periodSeconds: 5
>             failureThreshold: 12    # 12 x 5 s = up to 60 s to start
```
The startup probe checks `/healthz` every 5 seconds and tolerates 12 failures: the app has up to 60 seconds. Liveness and readiness wait until it passes, then liveness works as before and still protects against a hang later.

By hand (this replaces `./fix.sh`, so you don't need to run both): apply the fixed file from the `fix` folder.
```bash
kubectl apply -f app.yaml
```
Kubernetes starts a new Pod with the startup probe and removes the old one.

## ✅ Verify it yourself
```bash
kubectl get pods -n k-07-slow-start
```
```
NAME                        READY   STATUS    RESTARTS   AGE
showdown-7597cc744f-7qvd8   1/1     Running   0          27s
visitor                     1/1     Running   0          3m12s
```
(Ages and Pod names will differ.) One app Pod, `1/1` Ready and `0` restarts, and it stays that way. The visitor's log is green (if you still see a ❌, wait a few seconds and run it again):
```bash
kubectl logs visitor -n k-07-slow-start --tail=3
```
```
✅ 04:09:49 HTTP 200
✅ 04:09:51 HTTP 200
✅ 04:09:53 HTTP 200
```
The app's own log shows the 20-second wake-up completing, with no kill in between:
```bash
kubectl logs -n k-07-slow-start -l app=showdown
```
```
2026-11-08T04:09:24 [showdown-7597cc744f-7qvd8] simulating slow startup: sleeping 20.0s
2026-11-08T04:09:44 [showdown-7597cc744f-7qvd8] 🚀 Cats vs Dogs v1.0.0 (Cats vs Dogs) listening on :8080, votes stored in MEMORY (this container only)
```
And both probes are on the Pod:
```bash
kubectl describe pod -n k-07-slow-start -l app=showdown | grep -E 'Startup:|Liveness:'
```
```
    Liveness:       http-get http://:8080/healthz delay=5s timeout=1s period=5s #success=1 #failure=1
    Startup:        http-get http://:8080/healthz delay=0s timeout=1s period=5s #success=1 #failure=12
```
(`kubectl describe` may also list a few `Startup probe failed` events from the first 20 seconds. They are harmless: the app was still waking up, and the startup probe is allowed 12 failures.) Now open it yourself. In a **second terminal** (leave it running):
```bash
kubectl port-forward -n k-07-slow-start --address 0.0.0.0 svc/showdown 9207:80
```
```
Forwarding from 0.0.0.0:9207 -> 8080
```
Back in the first terminal:
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:9207
```
```
200
```
Or open http://localhost:9207 in your browser and cast a vote (playground: open the URL for port 9207). Press Ctrl+C in the second terminal to stop the port-forward.

## 🎯 Key takeaways
- **Liveness restarts; startup waits.** A liveness probe that fires before the app is up kills a healthy app over and over.
- **Give slow starters a `startupProbe`.** Budget = `periodSeconds` × `failureThreshold` (here 5 × 12 = 60 s). Liveness only begins once it passes.
- **No crash, no error.** The only clues are the `Killing … failed liveness probe` event and a log that stops mid-start-up.
- Debug path: `get pods -w` (rising restarts) → `describe` (liveness failed, killed) → `logs --previous` ("simulating slow startup") → the probe settings in the Deployment.

## 💎 Lifelong lesson
> Never let liveness judge an app that hasn't finished waking up.

## 🧹 Clean up
Press Ctrl+C in the port-forward terminal first, then:
```bash
cd .. && ./cleanup.sh
```

## Next →
[K08](../08-ai-trainer-oomkilled/README.md): Exit 137 means someone killed it…
