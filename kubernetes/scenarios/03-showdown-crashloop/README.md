# K03 · The loop

*It starts. It dies. It starts. It dies. Welcome to the loop.*

⏱ 10 min · beginner · Cats vs Dogs voting app (`python:3.12-alpine`, about 19 MB) · restartPolicy, CrashLoopBackOff, back-off, `logs --previous`

⬇️ First run downloads about 19 MB (Python) plus a tiny 4 MB visitor image. A slow first download is normal: do it on good Wi-Fi, before the session.

Output columns and wording can differ a little between kubectl, container runtimes and clusters (kind, minikube, Docker Desktop, playgrounds). The ideas never change.

## 📖 The story
It's exam week at Christ University and Meera is deploying the class "Cats vs Dogs" poll. The app reads the port it should listen on from a setting called `PORT`. Late at night, she "makes the config friendlier" and writes `eighty` instead of `8080`. `kubectl` says `created`. A minute later the Pod says `Running`... then `Error`... then `CrashLoopBackOff`. The poll is down, and the Pod seems to restart all by itself.

## 🧠 The concept: why, what, how
A Pod's **restartPolicy** tells the kubelet (the agent on each node) what to do when a container exits. For Deployments it is `Always`: if the container stops, for any reason, start it again. That is how Kubernetes heals a crashed app without waking you up.

- But a container that crashes *immediately*, every time, would be restarted in a tight loop and waste the node. So the kubelet **backs off**: it waits about 10 s, then 20 s, 40 s… up to 5 minutes between restarts. Think of a friend who keeps ringing your doorbell, but waits longer each time.
- **`CrashLoopBackOff`** is that waiting period. It is not an error by itself: it means "this container keeps dying, and I'm pausing before the next try".
- The restarted container is a *new* one. The old one is dead, but its last output is kept, so you can read it with **`kubectl logs --previous`**.

```
 start ──▶ crash ──▶ wait 10s ──▶ start ──▶ crash ──▶ wait 20s ──▶ start ──▶ crash ──▶ wait 40s …
              │                                │
              └── RESTARTS goes up each time ──┘   (the last words are kept: logs --previous)
```

## 🏢 Where you'll meet this at work
- **A bad config value:** a number that is really a word, a typo in an env var, a missing setting (developer, SRE).
- **A missing environment variable** after a deploy to a new environment, so the app refuses to start (developer, platform team).
- **A migrated database URL:** the app starts, can't connect to the new address, and exits on purpose (SRE).

## 💥 Break it
```bash
cd break && ./break.sh
```
What the room should see: the script says the app was deployed, but it keeps starting and dying. The Deployment exists, a Pod exists, and nobody can vote. A small `visitor` Pod keeps asking the app for `/healthz` every 2 seconds and gets no answer:
```bash
kubectl logs -f visitor -n k-03-crashloop
```
```
❌ 00:55:46 no answer from http://showdown/healthz
❌ 00:55:49 no answer from http://showdown/healthz
❌ 00:55:52 no answer from http://showdown/healthz
```
You can stop it with Ctrl+C. We'll watch it again live when we fix things.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. What state is the Pod in?**
```bash
kubectl get pods -n k-03-crashloop
```
```
NAME                        READY   STATUS             RESTARTS      AGE
showdown-7cf5b87cb4-tf98v   0/1     CrashLoopBackOff   1 (10s ago)   12s
visitor                     1/1     Running            0             12s
```
(Ages and Pod names will differ.) Run it again a minute later: `RESTARTS` keeps climbing, and `STATUS` flips between `Error` and `CrashLoopBackOff`. Unlike an image problem, the container *did* start: it just doesn't stay alive. The `visitor` is fine, so the cluster works. Only the app Pod is dying.

<details><summary>💡 Hint</summary>
The container starts, runs for a moment and exits. What does the dead container say? Where does Kubernetes keep the last words of a container that is already gone? And which setting did the app read right at startup?
</details>

**2. How did it die?** `describe` shows the last state of the container.
```bash
kubectl describe pod -n k-03-crashloop -l app=showdown | grep -A6 'Last State'
```
```
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Sun, 08 Nov 2026 06:26:04 +0530
      Finished:     Sun, 08 Nov 2026 06:26:04 +0530
    Ready:          False
    Restart Count:  2
```
It was `Terminated` with `Exit Code: 1`, which usually means "the app itself failed" (2 or 127 would hint at a bad command, 137 at being killed). Look at `Started` and `Finished`: the same second. The app died instantly, so this is not a slow leak or a failing probe. It never got going.

**3. Ask the corpse: what were its last words?** The current container has just been restarted and is silent, so ask for the *previous* one.
```bash
kubectl logs -n k-03-crashloop -l app=showdown --previous
```
```
Traceback (most recent call last):
  File "/app/app.py", line 45, in <module>
    PORT = int(os.environ.get("PORT", "8080"))
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: invalid literal for int() with base 10: 'eighty'
```
(The `^^^^` marker lines depend on the Python version.) There it is, in the app's own words: line 45 turns the `PORT` setting into a number with `int(...)`, and the value is `'eighty'`, which is not a number. Plain `kubectl logs` (without `--previous`) may show the same text, but right after a restart it can be empty. `--previous` is the one to trust.

**4. Where does `eighty` come from?**
```bash
kubectl get deploy showdown -n k-03-crashloop -o yaml | grep -A1 'name: PORT'
```
```
        - name: PORT
          value: eighty
```
The Deployment sets `PORT` to the word `eighty`. The app needs digits.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The Deployment sets the environment variable `PORT: "eighty"`. At startup the app runs `int(os.environ["PORT"])`, which raises `ValueError` for a word, so the process exits with code 1 before it listens on anything. Because the Deployment's restartPolicy is `Always`, the kubelet starts it again, it dies again, and the waits between tries grow: `CrashLoopBackOff`. Nothing is wrong with the image, the node or the network.
</details>

## 🔧 Fix it
Before you run it, open a **second terminal** and start the live visitor log, so the room sees red turn green:
```bash
kubectl logs -f visitor -n k-03-crashloop
```
Then, in the first terminal:
```bash
cd ../fix && ./fix.sh
```
Within a few seconds the log flips from ❌ to ✅ lines (Ctrl+C to stop it). It doesn't wait for the back-off timer: changing the Pod template makes a **new** Pod, and a new Pod starts straight away. What changed: just the value of `PORT`.
```bash
diff ../break/app.yaml app.yaml
```
```
1c1
< # K03 break: PORT is set to the word "eighty" instead of the number 8080, so the app crashes at start.
---
> # K03 fix: PORT is the number 8080.
23c23
<               value: "eighty"    # a word, not a number
---
>               value: "8080"
```

By hand (this replaces `./fix.sh`, so you don't need to run both): apply the fixed file from the `fix` folder.
```bash
kubectl apply -f app.yaml
```
Kubernetes starts a new Pod with the right value and removes the crashing one. (The one-line alternative is `kubectl set env deploy/showdown -n k-03-crashloop PORT=8080`.)

## ✅ Verify it yourself
```bash
kubectl get pods -n k-03-crashloop
```
```
NAME                       READY   STATUS    RESTARTS   AGE
showdown-78bbc546b-kg8fd   1/1     Running   0          9s
visitor                    1/1     Running   0          50s
```
(Ages and Pod names will differ.) One app Pod, `Running`, `1/1` Ready and `0` restarts. The crashing one is gone. The visitor's log is green again (if you still see a ❌, wait a few seconds and run it again):
```bash
kubectl logs visitor -n k-03-crashloop --tail=3
```
```
✅ 00:56:26 HTTP 200
✅ 00:56:28 HTTP 200
✅ 00:56:30 HTTP 200
```
And the app's own log now says what it is doing:
```bash
kubectl logs -n k-03-crashloop -l app=showdown
```
```
2026-11-08T00:56:23 [showdown-78bbc546b-kg8fd] 🚀 Cats vs Dogs v1.0.0 (Cats vs Dogs) listening on :8080, votes stored in MEMORY (this container only)
```
Now open it yourself. In a **second terminal** (leave it running):
```bash
kubectl port-forward -n k-03-crashloop --address 0.0.0.0 svc/showdown 9203:80
```
```
Forwarding from 0.0.0.0:9203 -> 8080
```
Back in the first terminal:
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:9203
```
```
200
```
Or open http://localhost:9203 in your browser and cast a vote (playground: open the URL for port 9203). Press Ctrl+C in the second terminal to stop the port-forward.

## 🎯 Key takeaways
- **restartPolicy `Always` restarts a dead container, but waits longer each time** (about 10 s up to 5 min). That waiting is `CrashLoopBackOff`.
- **`CrashLoopBackOff` is a symptom, not a cause.** The container did start, then died. Read the exit code (`describe`) and the last words (`logs --previous`).
- **`kubectl logs --previous` reads the dead container.** Plain `logs` shows the new one, which may not have said anything yet.
- A changed Pod template makes a new Pod, which starts immediately: no need to wait out the back-off.

## 💎 Lifelong lesson
> When it keeps dying, ask the corpse: `logs --previous`.

## 🧹 Clean up
Press Ctrl+C in the port-forward terminal first, then:
```bash
cd .. && ./cleanup.sh
```

## Next →
[K04](../04-it-tools-no-endpoints/README.md): Every Pod is Running. Every request fails.
