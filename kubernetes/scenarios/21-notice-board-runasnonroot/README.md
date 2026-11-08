# K21 · The rule that turned the lights off

*Security turned on one rule. The notice board went dark.*

⏱ 12 min · beginner · Campus notice board (a small offline HTML page, served by `nginx:1.27.5-alpine`) · Pod security settings, running as a normal user

⬇️ The tiny 4 MB visitor image downloads when you break it. The nginx image (about 21 MB) is already needed at break time, and the replacement image `nginxinc/nginx-unprivileged:1.27.5-alpine` (about 22 MB) downloads only at fix time. On a cold cluster the fix moment waits on that download (up to a minute or two). Presenters: preload it (`kubernetes/scenarios/preload.sh`) or run the scenario once before class, on good Wi-Fi.

Output columns and wording can differ a little between kubectl versions and clusters (kind, minikube, Docker Desktop, playgrounds). The ideas never change.

## 📖 The story
Lakshmi runs the **Campus notice board**, a page that lists fest dates, the canteen menu and the lost-and-found. It has been running happily for weeks. Yesterday the security team rolled out a new policy for every app on the cluster, and Ravi updated the notice board's Deployment to follow it. Now the Pods will not come up, and the whole college is staring at an empty board.

## 🧠 The concept: why, what, how
By default, a container in Kubernetes runs as whatever user its image says, and many images say **root**, the all-powerful user. If a root process is hijacked, the attacker starts with a lot of power. So security teams ask: "never run as root".

- `securityContext.runAsNonRoot: true` is a **guard** on the Pod: "refuse to start any container that would run as user 0 (root)".
- The guard **checks, it does not change**. It does not switch your container to a different user; it only says no. Kubernetes looks at the user the image declares (or the `runAsUser` you set). If that is root, or if it cannot tell the user is a number, the container is never created.
- To pass the guard, the *image* must be built for a normal user (most often a numeric non-zero user), and everything that user touches (files, ports) must suit it. Normal users cannot listen on ports below 1024.
- Analogy: the guard is a bouncer who refuses anyone wearing a "master key" badge. The bouncer does not take the badge off for you. You must bring someone who never carried one.

```
 Pod: runAsNonRoot: true   "refuse any container that would run as root"
          │
 image says "root" (user 0)  ──▶ refused    → CreateContainerConfigError, no container
 image says "user 101"       ──▶ allowed    → Running
```

## 🏢 Where you'll meet this at work
- **Company-wide Pod security rules.** Platform and security teams require non-root containers (the "restricted" Pod Security Standard), and every team's Deployment must pass (platform team, security engineers, developers).
- **Managed clusters and OpenShift.** Some platforms assign a random non-root user to every container, so images that insist on being root fail there (developer, SRE).
- **Choosing base images.** Teams keep a list of approved "unprivileged" images exactly so that this guard passes (platform team).

## 💥 Break it
```bash
cd break && ./break.sh
```
What the room should see: the script deploys the notice board and finishes. Two `board` Pods are not running. A small `visitor` Pod, which asks for the board every few seconds, gets no answer:
```bash
kubectl logs -f visitor -n k-21-nonroot
```
```
❌ 20:02:43 no answer from http://board
❌ 20:02:46 no answer from http://board
```
(Times will differ.) You can stop it with Ctrl+C. We'll watch it again live when we fix things.

## 🔍 Investigate
Guess first, then run these **in order**. The visitor's log already told us the symptom: nobody answers.

**1. What state are the Pods in?** Start with the Pods, always.
```bash
kubectl get pods -n k-21-nonroot
```
```
NAME                     READY   STATUS                       RESTARTS   AGE
board-85fd494b8f-hzbwq   0/1     CreateContainerConfigError   0          13s
board-85fd494b8f-r6cps   0/1     CreateContainerConfigError   0          13s
visitor                  1/1     Running                      0          13s
```
(Ages and Pod names will differ. Right after `break.sh`, one Pod may still say `ContainerCreating` for a second.) The `visitor` runs, but both `board` Pods say `CreateContainerConfigError`, with `0` restarts: the container was never even created. That is different from a crash: nothing ran and died.

<details><summary>💡 Hint</summary>
The image is fine, it was pulled (or was already there), and the Pod was given a node. Something about the container's <em>configuration</em> made the kubelet refuse to create it. Ask the Pod for its last words, then look at what the Deployment says about how the Pod must behave. What changed yesterday?
</details>

**2. What did the kubelet say?** The kubelet (the node's agent) leaves a note on the Pod when it refuses. Use one of your own Pod names from step 1:
```bash
kubectl describe pod board-85fd494b8f-hzbwq -n k-21-nonroot | grep -A8 '^Events'
```
```
Events:
  Type     Reason     Age              From               Message
  ----     ------     ----             ----               -------
  Normal   Scheduled  1s               default-scheduler  Successfully assigned k-21-nonroot/board-85fd494b8f-hzbwq to z2h-test-worker2
  Normal   Pulled     0s (x2 over 1s)  kubelet            spec.containers{board}: Container image "nginx:1.27.5-alpine" already present on machine
  Warning  Failed     0s (x2 over 1s)  kubelet            spec.containers{board}: Error: container has runAsNonRoot and image will run as root (pod: "board-85fd494b8f-hzbwq_k-21-nonroot(715b9011-f439-40a2-81a2-298831fc20ba)", container: board)
```
(shortened; names, ages and the node will differ. The exact wording is Kubernetes-version dependent: older and newer versions word the first lines a little differently, so look for the `Failed` line that mentions `runAsNonRoot`.) The Pod was scheduled, the image arrived, and then the kubelet refused: the Pod demands "non-root", but this image would run as root.

**3. Where does the demand come from?** The event says `runAsNonRoot`. Find it in the Deployment's Pod template.
```bash
kubectl get deploy board -n k-21-nonroot -o jsonpath='{.spec.template.spec.securityContext}'
```
```
{"runAsNonRoot":true}
```
There is the guard: the Pod must not run as root. And the image? The official `nginx` image declares no other user, so its main process starts as root (it needs root to listen on port 80 and to write into its own root-owned folders). The guard and the image disagree, so the container is never created.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The Deployment carries `securityContext.runAsNonRoot: true` (the security team's new rule), but `nginx:1.27.5-alpine` is built to start as root. Kubernetes checks this *before* creating the container, so the Pod stays in `CreateContainerConfigError`. Nothing is wrong with the policy, the page, the Service or the capacity: the image does not fit the rule.
</details>

## 🔧 Fix it
Before you run it, open a **second terminal** and start the live visitor log, so the room sees red turn green:
```bash
kubectl logs -f visitor -n k-21-nonroot
```
Then, in the first terminal:
```bash
cd ../fix && ./fix.sh
```
Within about twenty seconds once the new image is downloaded (the first time, up to a minute or two) the log flips from ❌ to ✅ lines (Ctrl+C to stop it):
```
❌ 20:02:55 no answer from http://board
✅ 20:02:57 HTTP 200
✅ 20:02:59 HTTP 200
```
(shortened.) What changed:
```bash
diff ../break/app.yaml app.yaml
```
```
1,2c1
< # K21 break (2/3): the Campus notice board, served by plain nginx.
< # The security team rolled out a new policy yesterday; this Deployment was updated to follow it.
---
> # K21 fix: the same notice board and the same policy, but on an image built to run as a normal user.
18c17
<       # Added by the security team.
---
>       # Added by the security team. Unchanged: the policy stays.
23c22,23
<           image: nginx:1.27.5-alpine
---
>           # nginx-unprivileged runs as user 101 and listens on 8080 (a normal user may not use ports below 1024).
>           image: nginxinc/nginx-unprivileged:1.27.5-alpine
25c25
<             - containerPort: 80
---
>             - containerPort: 8080
29c29
<               port: 80
---
>               port: 8080
48c48
<       targetPort: 80
---
>       targetPort: 8080
```
Three things moved together: the **image** (built to run as user 101), the **container port** (8080, because a normal user may not use ports below 1024) and the Service's **targetPort** (so traffic still reaches the right port; the Service itself still answers on 80). The `securityContext` was not touched. The page is mounted at the same path, `/usr/share/nginx/html`, in both images.

By hand (this replaces `./fix.sh`, so you don't need to run both): from the `fix` folder, apply the corrected file.
```bash
kubectl apply -f app.yaml
```

**Why not just delete `runAsNonRoot`?** Because it would work, and that is the trap. The board would come up in seconds, and you would have quietly switched off the security team's rule for this app, and you would be the person who did it. A guard that is removed whenever it is inconvenient is not a guard. The policy was right: running a web server as root gives an attacker far more than they need. The thing that did not fit was the image, so the image is what we change.

**Why not set `runAsUser: 101` on the original image?** It is tempting, and it passes the guard, but the plain `nginx` image was built for root. It wants to write its PID file and caches into root-owned folders and to listen on port 80, which a normal user is not allowed to do. The Pod would get past the guard and then crash with permission errors, and you would patch that with more settings, one fragile fix at a time. (That path exists, and is sometimes the only option for an image you cannot replace, but you must then fix every path and port yourself.) An image built for a normal user does all of this by design.

## ✅ Verify it yourself
```bash
kubectl get pods -n k-21-nonroot
```
```
NAME                     READY   STATUS    RESTARTS   AGE
board-5695884889-rh282   1/1     Running   0          5s
board-5695884889-s6mfs   1/1     Running   0          7s
visitor                  1/1     Running   0          20s
```
(Names and ages will differ.) Both board Pods are `Running`. Is the guard still on? And who is the board really running as?
```bash
kubectl get deploy board -n k-21-nonroot -o jsonpath='{.spec.template.spec.securityContext}{"\n"}'
kubectl exec deploy/board -n k-21-nonroot -- id
```
```
{"runAsNonRoot":true}
uid=101(nginx) gid=101(nginx) groups=101(nginx)
```
The rule is still there, and the board runs as user 101. The visitor's log is green (if you still see a ❌, wait a few seconds and run it again):
```bash
kubectl logs visitor -n k-21-nonroot --tail=3
```
```
✅ 20:02:57 HTTP 200
✅ 20:02:59 HTTP 200
✅ 20:03:01 HTTP 200
```
Now look at the board yourself. In a **second terminal** (leave it running):
```bash
kubectl port-forward -n k-21-nonroot svc/board 9221:80
```
```
Forwarding from 127.0.0.1:9221 -> 8080
Forwarding from [::1]:9221 -> 8080
```
On a playground, add `--address 0.0.0.0` and open the URL for port 9221.
Back in the first terminal:
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:9221
```
```
200
```
(The port-forward terminal also prints `Handling connection for 9221`.) Or open http://localhost:9221 in your browser: click the tabs, and claim the lost earbud. The page needs no internet. Press Ctrl+C in the second terminal to stop the port-forward.

## 🎯 Key takeaways
- **`runAsNonRoot: true` is a guard, not a switch.** It refuses root; it never changes the user for you.
- **`CreateContainerConfigError` means the container was never created.** `kubectl describe pod` → Events says why.
- **Normal users cannot use ports below 1024 or write to root-owned folders.** "Unprivileged" images move to port 8080 and use writable paths for exactly this reason.
- Fix the side that is wrong: the image does not fit the rule, so change the image. Do not delete the rule, and do not paper over it with `runAsUser` on an image built for root.

## 💎 Lifelong lesson
> Fix the image, not the policy. Weakening security is never the fix.

## 🧹 Clean up
Press Ctrl+C in the port-forward terminal first, then:
```bash
cd .. && ./cleanup.sh
```

## Next →
[K22](../22-notice-board-readonly-fs/README.md): Locked down perfectly. Now it can't even start.
