# K24 · The app that never ran

*No crash log. No error from the app. The app never even ran.*

⏱ 10 min · beginner · Cats vs Dogs voting app (`python:3.12-alpine`, about 19 MB) · container start-up, `kubectl logs` vs Events, restart count, `describe`

⬇️ First run downloads about 19 MB (Python) plus a tiny 4 MB visitor image. A slow first download is normal: do it on good Wi-Fi, before the session.

Output columns and wording can differ a little between kubectl, container runtimes and clusters (kind, minikube, Docker Desktop, playgrounds). The ideas never change.

## 📖 The story
Priya is helping the Christ University fest team ship the "Cats vs Dogs" poll for the inter-department showdown. The deploy file was copied from last year's, and she tidied it up just before leaving the lab. `kubectl` says `created`. The Pod never turns green, and the restart counter keeps climbing. She runs `kubectl logs` to see what the app is complaining about, and gets... nothing. Not an error. Not a traceback. A blank line, and a poll nobody can vote in.

## 🧠 The concept: why, what, how
Starting a container is two steps, done by two different parties. The **kubelet** (the agent on each node) asks the container runtime to create the container, and the runtime then tries to **execute** the program it was told to run. Only after that does *your* code run, and only your code writes to `kubectl logs`.

- If the program can't be started at all (the file isn't there, or it isn't executable), the runtime reports the failure to the kubelet, and the kubelet records it as an **Event**. Your app never ran, so it has nothing to say.
- That is the difference from [K03](../03-showdown-crashloop/README.md), where the app *did* start, ran its own code and crashed with a traceback you could read in `logs --previous`. Here the kubelet could not even exec the program.
- The status names depend on the runtime and the moment: you may see `RunContainerError` and `CrashLoopBackOff` alternate, with `StartError` as the container's last state. Same cause, different moment. Other runtimes (CRI-O, Docker Desktop) may use a different reason or exit code; the constant is the `executable file not found` text.

Think of a taxi booking. K03 is a driver who arrives and then drives off the road. K24 is a booking app that sends the driver to an address that doesn't exist: there is no journey to report, only the dispatcher's note that the pickup failed.

```
 kubelet ──▶ runtime ──▶ exec the program ──▶ your app runs ──▶ writes logs
                              │
                              └── not found? ──▶ error goes to Events (not to logs)
```

## 🏢 Where you'll meet this at work
- **A wrong path or name in a container's start-up line** after a refactor or a copy-paste from another project (developer, SRE).
- **A slim or "distroless" base image** that doesn't contain the shell or tool your start-up line expects (developer, platform team).
- **A CI-built image that lost its entry file** when someone changed the Dockerfile `COPY` lines (developer, SRE).

## 💥 Break it
```bash
cd break && ./break.sh
```
What the room should see: the script says the app was deployed, but nobody can vote. A small `visitor` Pod keeps asking the app for `/healthz` every 2 seconds and gets no answer:
```bash
kubectl logs -f visitor -n k-24-never-ran
```
```
❌ 20:11:29 no answer from http://showdown/healthz
❌ 20:11:32 no answer from http://showdown/healthz
❌ 20:11:35 no answer from http://showdown/healthz
```
You can stop it with Ctrl+C. We'll watch it again live when we fix things.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. What state is the Pod in?**
```bash
kubectl get pods -n k-24-never-ran
```
```
NAME                        READY   STATUS             RESTARTS      AGE
showdown-664d656997-ffhrx   0/1     CrashLoopBackOff   1 (17s ago)   18s
visitor                     1/1     Running            0             18s
```
(Ages and Pod names will differ.) The restart count is already going up. Run it again a few times: `STATUS` can also read `RunContainerError` for a moment, alternating with `CrashLoopBackOff`.
The `visitor` is fine, so the cluster works. Only the app Pod is stuck.

<details><summary>💡 Hint</summary>
Every other time a Pod misbehaved, the app's own words told us what was wrong. Ask the app what it has to say. If it says nothing at all, what does that tell you about whether it ever got a turn? And if the app can't tell us, who else writes things down about a Pod?
</details>

**2. What does the app say?** The natural first move for any sick Pod is its logs.
```bash
kubectl logs -n k-24-never-ran -l app=showdown
```
```
(no output)
```
Nothing. (Your terminal just returns to the prompt.) The `--previous` flag won't help either, the dead container never wrote a line:
```bash
kubectl logs -n k-24-never-ran -l app=showdown --previous
```
```
(no output)
```
Also nothing (some runtimes print `previous terminated container not found` instead, which says the same thing). That silence **is** the clue: a program that ran and crashed leaves words behind, as K03 showed. A program that never ran leaves none. So the answer is not in the logs. It's in what Kubernetes itself recorded.

**3. How did the container end?** `describe` shows the container's last state, and the restart count.
```bash
kubectl describe pod -n k-24-never-ran -l app=showdown | grep -A8 'Last State'
```
```
    Last State:     Terminated
      Reason:       StartError
      Message:      failed to create containerd task: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: exec: "pyhton": executable file not found in $PATH
      Exit Code:    128
      Started:      Thu, 01 Jan 1970 05:30:00 +0530
      Finished:     Mon, 09 Nov 2026 01:41:28 +0530
    Ready:          False
    Restart Count:  1
    Readiness:      http-get http://:8080/readyz delay=0s timeout=1s period=10s #success=1 #failure=3
```
(Wording, reason and exit code differ by runtime: `StartError` and `containerd` here, something else on CRI-O or Docker Desktop, and some show no `Started` date.) Look at what is *missing*: the container was never really `Started` (that 1970 date is just "zero"), the exit code is 128 rather than the app's own, and the message comes from the runtime. It says it tried to run a program called `"pyhton"` and couldn't find it. `Restart Count` shows the kubelet tried again anyway.

**4. What else did Kubernetes write down?** The Events at the bottom of `describe` are the kubelet's diary.
```bash
kubectl describe pod -n k-24-never-ran -l app=showdown | sed -n '/^Events:/,$p'
```
```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  18s                default-scheduler  Successfully assigned k-24-never-ran/showdown-664d656997-ffhrx to z2h-test-worker
  Normal   Pulled     17s (x2 over 17s)  kubelet            spec.containers{showdown}: Container image "python:3.12-alpine" already present on machine
  Normal   Created    17s (x2 over 17s)  kubelet            spec.containers{showdown}: Created container: showdown
  Warning  Failed     17s (x2 over 17s)  kubelet            spec.containers{showdown}: Error: failed to create containerd task: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: exec: "pyhton": executable file not found in $PATH
  Warning  BackOff    7s (x2 over 16s)   kubelet            spec.containers{showdown}: Back-off restarting failed container showdown in pod showdown-664d656997-ffhrx_k-24-never-ran(571b015a-700d-4c71-9a61-c8f96cf68951)
```
(Wording and order of lines differ by Kubernetes version and runtime. The `Failed` line is the one to look for.) The image was pulled fine, the container was created, and then the `Failed` event says `exec: "pyhton": executable file not found in $PATH`. The runtime looked for a program with that name and there is none.

**5. Where does `pyhton` come from?**
```bash
kubectl get deploy showdown -n k-24-never-ran -o yaml | grep -A2 'command:'
```
```
      - command:
        - pyhton
        - /app/app.py
```
The Deployment tells the container to start by running `pyhton`. The image has `python`. One letter swapped.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The Deployment sets `command: ["pyhton", "/app/app.py"]`, a typo of `python`. When the kubelet asked the runtime to start the container, the runtime searched `$PATH` for a program called `pyhton`, found none, and refused to start the container (`executable file not found in $PATH`). Since the app never ran, `kubectl logs` was empty; the only record is in the Events and in the container's `describe` state. Because restartPolicy is `Always`, the kubelet kept trying, which is why the restart count rose and the status became `CrashLoopBackOff`. The image, the node and the network were fine.
</details>

## 🔧 Fix it
Before you run it, open a **second terminal** and start the live visitor log, so the room sees red turn green:
```bash
kubectl logs -f visitor -n k-24-never-ran
```
Then, in the first terminal:
```bash
cd ../fix && ./fix.sh
```
Within a few seconds the log flips from ❌ to ✅ lines (Ctrl+C to stop it). A changed Pod template makes a **new** Pod, which starts straight away without waiting for the back-off timer. What changed: one word.
```bash
diff ../break/app.yaml app.yaml
```
```
1c1
< # K24 break: the Cats vs Dogs app, deployed.
---
> # K24 fix: the Cats vs Dogs app, corrected.
20c20
<           command: ["pyhton", "/app/app.py"]
---
>           command: ["python", "/app/app.py"]
```

By hand (this replaces `./fix.sh`, so you don't need to run both): apply the fixed file from the `fix` folder.
```bash
kubectl apply -f app.yaml
```
Kubernetes starts a new Pod with the right program name and removes the old one.

## ✅ Verify it yourself
```bash
kubectl get pods -n k-24-never-ran
```
```
NAME                        READY   STATUS    RESTARTS   AGE
showdown-598996fc89-vxrtg   1/1     Running   0          9s
visitor                     1/1     Running   0          35s
```
(Ages and Pod names will differ.) One app Pod, `Running`, `1/1` Ready and `0` restarts. The visitor's log is green again (if you still see a ❌, wait a few seconds and run it again):
```bash
kubectl logs visitor -n k-24-never-ran --tail=3
```
```
✅ 20:11:56 HTTP 200
✅ 20:11:58 HTTP 200
✅ 20:12:00 HTTP 200
```
And now the app has something to say, because it finally got to run:
```bash
kubectl logs -n k-24-never-ran -l app=showdown
```
```
2026-11-08T20:11:54 [showdown-598996fc89-vxrtg] 🚀 Cats vs Dogs v1.0.0 (Cats vs Dogs) listening on :8080, votes stored in MEMORY (this container only)
```
Now open it yourself. In a **second terminal** (leave it running):
```bash
kubectl port-forward -n k-24-never-ran svc/showdown 9224:80
```
```
Forwarding from 127.0.0.1:9224 -> 8080
Forwarding from [::1]:9224 -> 8080
```
On a playground, run the same command with `--address 0.0.0.0` added, and open the URL for port 9224.
Back in the first terminal:
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:9224
```
```
200
```
Or open http://localhost:9224 in your browser and cast a vote. Press Ctrl+C in the second terminal to stop the port-forward.

## 🎯 Key takeaways
- **Empty `kubectl logs` can mean the app never started.** A program that ran leaves words; one that never ran leaves none.
- **Two different failures, two different places to look.** The app ran and died: `logs --previous` ([K03](../03-showdown-crashloop/README.md)). The kubelet couldn't start it: `describe` and Events.
- **`executable file not found in $PATH` means the start-up line names something that isn't in the image.** Check the spelling and the path against what the image really contains.
- Status names vary (`RunContainerError`, `StartError`, `CrashLoopBackOff`), but the Events always carry the real reason.

## 💎 Lifelong lesson
> No logs means it never started. The answer is in the Events.

## 🧹 Clean up
Press Ctrl+C in the port-forward terminal first, then:
```bash
cd .. && ./cleanup.sh
```

## Next →
[K25](../25-showdown-hpa-not-scaling/README.md): Traffic is pouring in. The autoscaler shrugs: "unknown".
