# K11 · The Friday release

*Friday, 6 PM. The release goes out. Nobody notices… because Kubernetes saved you.*

⏱ 10 min · beginner · Cats vs Dogs voting app (`python:3.12-alpine`, about 19 MB) · rolling updates, readiness gating, `rollout status`, `rollout history`, `rollout undo`

⬇️ First run downloads about 19 MB (Python) plus a tiny 4 MB visitor image. A slow first download is normal: do it on good Wi-Fi, before the session.

Output columns and wording can differ a little between kubectl, container runtimes and clusters (kind, minikube, Docker Desktop, playgrounds). The ideas never change.

## 📖 The story
It's the Friday of the campus fest and Priya pushes "just a tiny change" to the Cats vs Dogs poll at 6 PM, because nobody wants to work on Monday. Her deploy tool reports "timed out" and she panics: is the poll down during the fest's busiest hour? Ravi opens a terminal, looks at who is actually voting right now... and everything is fine. Version 1 is still serving every single visitor. The broken version 2 never took a single vote.

## 🧠 The concept: why, what, how
A Deployment doesn't swap your app in one risky step. It does a **rolling update**: it starts a few new Pods, waits until they are *Ready*, and only then retires old ones. The Pods come from a **ReplicaSet**, one per version, so the old version stays around as a ready-made way back.

- **Readiness gating:** a new Pod only gets traffic after its readiness probe passes. A Pod that never becomes Ready never receives a single visitor.
- **`maxSurge: 1`, `maxUnavailable: 0`:** "you may start one extra Pod, but never take a Ready Pod away before a new one is Ready." Here that means the 3 old Pods stay until the new one proves itself, and it never does.
- **History and rollback:** every new Pod template is a numbered **revision**. `kubectl rollout undo` makes the Deployment use the previous template again: no files to find, no rebuild.

Think of a restaurant changing its chef: the new chef cooks one trial plate while the old chef keeps serving. Only when the plate is good does the old chef go home. If the plate is bad, the old chef never left.

```
 revision 1 (v1)   ReplicaSet A:  [Pod ✅] [Pod ✅] [Pod ✅]     ← all traffic goes here
 revision 2 (v2)   ReplicaSet B:  [Pod 💥]                      ← never Ready, gets nothing
                                   rollout waits... and waits...
```

## 🏢 Where you'll meet this at work
- **Every deploy you ever do:** a rolling update with a readiness probe is how most teams ship without downtime (developer, SRE).
- **Safer releases:** canary (try v2 on 5% of users first) and blue-green (two full copies, flip the switch) build on the same idea: keep the old version alive until the new one is proven (platform team).
- **Friday deploy freezes:** many companies forbid Friday releases. Rollback makes a bad Friday cheap, but nobody enjoys finding out on a weekend (everyone on call).

## 💥 Break it
```bash
cd break && ./break.sh
```
What the room should see: the script releases v1 and waits for all 3 Pods, then ships v2 ("🚀 Friday, 6 PM") and then goes quiet. Nothing looks on fire. A small `visitor` Pod asks the app which version it got, every 2 seconds:
```bash
kubectl logs -f visitor -n k-11-bad-rollout
```
```
✅ 09:02:53 v1.0.0
✅ 09:02:55 v1.0.0
✅ 09:02:57 v1.0.0
```
(Press Ctrl+C to stop.) It stays green and on **v1.0.0**: that is the point. The release is broken, and the users have not noticed.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is anybody hurt, and which Pods exist?** The visitor already told us nobody is: still ✅ v1.0.0. Now look at the Pods.
```bash
kubectl get pods -n k-11-bad-rollout
```
```
NAME                        READY   STATUS             RESTARTS     AGE
showdown-85c596fbc7-7h5dj   1/1     Running            0            22s
showdown-85c596fbc7-h4xp5   1/1     Running            0            22s
showdown-85c596fbc7-hdms8   1/1     Running            0            22s
showdown-86577586cd-wt9d6   0/1     CrashLoopBackOff   2 (3s ago)   19s
visitor                     1/1     Running            0            22s
```
(Ages and Pod names will differ.) Two Pod-name groups: three Pods share the prefix `showdown-85c596fbc7` and are Ready, and one Pod, `showdown-86577586cd`, is crash-looping. Three good Pods are serving, so no user is down. The odd one out is the new one.

<details><summary>💡 Hint</summary>
Why did Kubernetes leave the 3 healthy Pods alone, and why is there only one new Pod instead of three? Which setting makes it keep the old ones until a new one is Ready? And once you know which Pod is the broken one: what did it say before it died, and what is different about the new release?
</details>

**2. Why hasn't the release finished?** Ask the Deployment what the rollout is doing. The `--timeout=5s` makes it give up quickly instead of waiting (up to `progressDeadlineSeconds`, 10 minutes by default, after which it reports a deadline error).
```bash
kubectl rollout status deployment/showdown -n k-11-bad-rollout --timeout=5s
```
```
Waiting for deployment "showdown" rollout to finish: 1 out of 3 new replicas have been updated...
error: timed out waiting for the condition
```
One of the 3 new Pods exists, and the rest are never started, because the first one never becomes Ready. This is the "stuck" state: not failed, not finished.

**3. What are the two ReplicaSets doing?** Each version of the Pod template has its own ReplicaSet.
```bash
kubectl get rs -n k-11-bad-rollout
```
```
NAME                  DESIRED   CURRENT   READY   AGE
showdown-85c596fbc7   3         3         3       27s
showdown-86577586cd   1         1         0       24s
```
The old ReplicaSet (`85c596fbc7`) has 3 of 3 Ready. The new one (`86577586cd`) wants 1 and has 0 Ready. The rollout will not remove an old Pod until a new one is Ready.

**4. What was released, and when?** Every revision is recorded, with the reason someone wrote down.
```bash
kubectl rollout history deployment/showdown -n k-11-bad-rollout
```
```
deployment.apps/showdown 
REVISION  CHANGE-CAUSE
1         v1 good release
2         v2 Friday release
```
Revision 2 is the Friday release. The CHANGE-CAUSE column comes from the `kubernetes.io/change-cause` annotation on the Deployment: a note you leave for your future self.

**5. How did the new Pod die?** Use the name of the crashing Pod from step 1 (the one with `CrashLoopBackOff`; yours will differ).
```bash
kubectl logs showdown-86577586cd-wt9d6 -n k-11-bad-rollout --previous
```
```
Traceback (most recent call last):
  File "/app/app.py", line 45, in <module>
    PORT = int(os.environ.get("PORT", "8080"))
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: invalid literal for int() with base 10: 'eighty'
```
(The `^^^^` marker line depends on the Python version.) The new version is told `PORT` is the word `eighty`, so it dies at startup. `--previous` reads the dead container's last words; if you want a refresher, [K03](../03-showdown-crashloop/README.md) is entirely about this.

**6. What is different between v1 and v2?** Compare the settings stored in each revision.
```bash
kubectl rollout history deployment/showdown -n k-11-bad-rollout --revision=2 | grep -A1 -E 'APP_VERSION|PORT'
```
```
      APP_VERSION:	2.0.0
      PORT:	eighty
    Mounts:
```
```bash
kubectl rollout history deployment/showdown -n k-11-bad-rollout --revision=1 | grep -A1 -E 'APP_VERSION|PORT'
```
```
      APP_VERSION:	1.0.0
      PORT:	8080
    Mounts:
```
(The `Mounts:` line is just the next line of the output.) v2 ships `APP_VERSION 2.0.0` and `PORT eighty`; v1 had `1.0.0` and `8080`.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

Release v2 set `PORT: "eighty"`, so every v2 Pod crashes at startup and never passes its readiness probe. Because the Deployment uses `maxUnavailable: 0`, Kubernetes refuses to remove any Ready v1 Pod until a v2 Pod is Ready, and with `maxSurge: 1` it only ever starts one extra. So 3 v1 Pods keep serving, 1 v2 Pod crash-loops, and the rollout waits (up to `progressDeadlineSeconds`, 10 minutes by default, then it reports a deadline error). The users are fine; only the release is stuck.
</details>

## 🔧 Fix it
Before you run it, open a **second terminal** and start the live visitor log:
```bash
kubectl logs -f visitor -n k-11-bad-rollout
```
Then, in the first terminal:
```bash
cd ../fix && ./fix.sh
```
Expect the visitor to stay ✅ v1.0.0 the whole time: there was no outage to repair (Ctrl+C to stop it). The fix is a single command:
```bash
kubectl rollout undo deployment/showdown -n k-11-bad-rollout
```
It tells the Deployment to go back to the previous revision's Pod template. The old ReplicaSet already has 3 Ready Pods, so they simply stay, and the crash-looping Pod is removed. (`fix.sh` runs exactly this, then waits for the rollout to finish. kubectl may print a long warning about `kubectl apply`; it is harmless here.)

By hand (this replaces `./fix.sh`, so you don't need to run both):
```bash
kubectl rollout undo deployment/showdown -n k-11-bad-rollout
kubectl rollout status deployment/showdown -n k-11-bad-rollout
```
```
deployment.apps/showdown rolled back
deployment "showdown" successfully rolled out
```

## ✅ Verify it yourself
```bash
kubectl rollout history deployment/showdown -n k-11-bad-rollout
```
```
deployment.apps/showdown 
REVISION  CHANGE-CAUSE
2         v2 Friday release
3         v1 good release
```
Rolling back created a **new** revision, 3, with the old template and its old note. (Revision 1 became revision 3, so the numbers always go forward.) Now the Pods:
```bash
kubectl get pods -n k-11-bad-rollout
```
```
NAME                        READY   STATUS    RESTARTS   AGE
showdown-85c596fbc7-7h5dj   1/1     Running   0          33s
showdown-85c596fbc7-h4xp5   1/1     Running   0          33s
showdown-85c596fbc7-hdms8   1/1     Running   0          33s
visitor                     1/1     Running   0          33s
```
(Ages and Pod names will differ.) All 3 Ready, and they are the *same* Pods as in Investigate step 1 (`7h5dj`, `h4xp5`, `hdms8`): same names, ages that kept counting up. (Your names will differ, but they will match the names you saw before the fix.) The rollback didn't even restart them. The visitor says the same thing:
```bash
kubectl logs visitor -n k-11-bad-rollout --tail=3
```
```
✅ 09:03:03 v1.0.0
✅ 09:03:05 v1.0.0
✅ 09:03:07 v1.0.0
```
Now open it yourself. In a **second terminal** (leave it running):
```bash
kubectl port-forward -n k-11-bad-rollout svc/showdown 9211:80
```
```
Forwarding from 127.0.0.1:9211 -> 8080
Forwarding from [::1]:9211 -> 8080
```
On a playground, add `--address 0.0.0.0` and open the URL for port 9211.
Back in the first terminal:
```bash
curl -s localhost:9211/api/info | grep -o '"version": "[^"]*"'
```
```
"version": "1.0.0"
```
Or open http://localhost:9211 in your browser and cast a vote. Press Ctrl+C in the second terminal to stop the port-forward.

## 🎯 Key takeaways
- **A rolling update with a readiness probe protects users from a bad release:** a new Pod that never becomes Ready never gets traffic, and `maxUnavailable: 0` keeps the old Pods until it does.
- **A stuck rollout is not an outage.** Check who is serving (the old Pods, the visitor) before you panic.
- **`rollout status`, `rollout history` and `rollout undo`** are the three commands for a release: is it moving, what was shipped, take it back.
- **Leave notes:** a `kubernetes.io/change-cause` makes history readable at 2 AM. Roll back first, then fix the cause (the file in Git still says `eighty`!) in calm daylight.

## 💎 Lifelong lesson
> Ship with a way back. Rollback is a feature, not a failure.

## 🧹 Clean up
Press Ctrl+C in the port-forward terminal first, then:
```bash
cd .. && ./cleanup.sh
```

## Next →
[K12](../12-showdown-dns-namespaces/README.md): The Redis is running. The app is running. And the app swears Redis does not exist.
