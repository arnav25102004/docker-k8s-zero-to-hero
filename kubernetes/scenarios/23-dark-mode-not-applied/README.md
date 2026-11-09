# K23 · Dark mode is on. The site is still white.

*Dark mode is ON in the config. The site is still blinding white.*

⏱ 10 min · beginner · "Campus Today" notice page (a tiny Python page, `python:3.12-alpine`, about 19 MB) · ConfigMaps, `envFrom`, `rollout restart`

⬇️ First run downloads about 19 MB (Python) plus a tiny 4 MB visitor image. A slow first download is normal: do it on good Wi-Fi, before the session.

Output columns and wording can differ a little between kubectl versions and clusters (kind, minikube, Docker Desktop, playgrounds). The ideas never change.

## 📖 The story
The campus has screens in the canteen, the library and the main gate, all showing the "Campus Today" page: lunch menu, library hours, the last bus. After 8 PM the white page glares in the dark corridors, so Meera from the design team asks for a dark theme. Ravi flips the setting in the config: `THEME: dark`. `kubectl` says `configmap/ui-settings patched`. He walks to the canteen. The screen is still blinding white. He checks the config again. It says dark. He checks it a third time. Still dark. So who is lying?

## 🧠 The concept: why, what, how
A **ConfigMap** keeps settings outside your container image, so one image can run in many places with different settings. A Pod can receive a ConfigMap in two main ways:

- **As environment variables** (`envFrom` or `env`): Kubernetes copies the values into the container's environment at the moment the container is created. After that, they are part of that running process.
- **As a mounted file**: the ConfigMap shows up as files in a folder. When the ConfigMap changes, Kubernetes eventually updates those files in running Pods (it can take a minute or so).

Analogy: the ConfigMap is the notice on the office board, the environment variable is what you wrote on your hand this morning. Changing the board doesn't change your hand.

So "I changed the config" and "the app uses the new config" are two different events, and something has to connect them.

## 🏢 Where you'll meet this at work
- **A feature flag, log level or API URL changed in a ConfigMap** and "nothing happened" in production (developer, SRE).
- **A rotated setting or password** that the running Pods still use, because they never started again (platform team).
- **Release pipelines** that deliberately restart the Pods whenever their config changes, so the two can never drift apart (DevOps, platform team).

## 💥 Break it
```bash
cd break && ./break.sh
```
What the room should see: the script deploys the page, waits until it is ready, and then the design team's change goes in. The script finishes without errors. A small `visitor` Pod keeps asking the site which theme it shows (it hopes for dark):
```bash
kubectl logs -f visitor -n k-23-dark-mode
```
```
❌ 00:02:18 the site is light, the design team wants dark
❌ 00:02:20 the site is light, the design team wants dark
```
(Times will differ.) You can stop it with Ctrl+C. We'll watch it again live when we fix things.

## 🔍 Investigate
Guess first, then run these **in order**. The symptom: the config says dark, the site says light.

**1. Is anything broken in the cluster?** Start with the basics: are the Pods and the ConfigMaps there?
```bash
kubectl get pods,configmap -n k-23-dark-mode
```
```
NAME                         READY   STATUS    RESTARTS   AGE
pod/theme-57d49d955c-cmfpf   1/1     Running   0          18s
pod/visitor                  1/1     Running   0          18s

NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      18s
configmap/theme-code         1      18s
configmap/ui-settings        1      18s
```
(Pod names and ages will differ.) Everything is `Running` and `1/1`. No restarts, no errors. A healthy-looking cluster with a wrong page.

<details><summary>💡 Hint</summary>
The config says one thing and the page shows another. Don't trust either of them yet: compare what the <em>ConfigMap</em> holds with what the <em>running container</em> actually has. And ask: when did each of them get its value?
</details>

**2. What does the config say?** First check that the change really went in.
```bash
kubectl get cm ui-settings -n k-23-dark-mode -o yaml
```
```
apiVersion: v1
data:
  THEME: dark
kind: ConfigMap
metadata:
  creationTimestamp: "2026-11-09T00:02:01Z"
  name: ui-settings
  namespace: k-23-dark-mode
```
(shortened: the `last-applied-configuration` annotation and a few ids are left out.) The ConfigMap says **`THEME: dark`**. The design team did their job.

**3. What does the running container see?** Ask the Pod itself, from the inside.
```bash
kubectl exec deploy/theme -n k-23-dark-mode -- printenv THEME
```
```
light
```
**Light.** The ConfigMap says dark and the container says light.

**4. What did the app itself report?** The app prints one line when it starts.
```bash
kubectl logs deploy/theme -n k-23-dark-mode
```
```
Campus Today is up on port 8080 (theme: light)
```
The app agrees with its environment: light.

**5. Where does the Pod get that variable?** See how the settings reach the container.
```bash
kubectl describe pod -n k-23-dark-mode -l app=theme | grep -A3 "Environment Variables from"
```
```
    Environment Variables from:
      ui-settings  ConfigMap  Optional: false
    Environment:   <none>
    Mounts:
```
The whole ConfigMap `ui-settings` is passed in as environment variables. So the container did get its value from the right place. The question is *when*.

**6. When did each side get its value?** Compare the moment the container started with the moment the ConfigMap changed.
```bash
kubectl get pod -n k-23-dark-mode -l app=theme -o jsonpath='Container started: {.items[0].status.containerStatuses[0].state.running.startedAt}{"\n"}'
kubectl get cm ui-settings -n k-23-dark-mode -o jsonpath='{range .metadata.managedFields[?(@.manager=="kubectl-patch")]}ConfigMap changed:  {.time}{"\n"}{end}'
```
```
Container started: 2026-11-09T00:02:02Z
ConfigMap changed:  2026-11-09T00:02:03Z
```
(The second command only reads *when* the patch happened from the ConfigMap's bookkeeping; it changes nothing.) (Times will differ, and the gap is only a couple of seconds here because `break.sh` patches the ConfigMap right after the page is ready; in real life it is often days.) The container started **before** the ConfigMap changed. The Pod is older than the change.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The Deployment passes the ConfigMap to the container as **environment variables** (`envFrom`). Kubernetes copies those values into the container once, when the container starts. The Pod started while `THEME` was `light`, so its process keeps `THEME=light` for its whole life. Patching the ConfigMap later changed the ConfigMap only: nothing tells a running Pod to start again, and a process cannot have its environment changed from outside. Nothing is broken: the ConfigMap is right, the Pod is healthy, and the app does exactly what it was told at startup.
</details>

## 🔧 Fix it
Before you run it, open a **second terminal** and start the live visitor log, so the room sees red turn green:
```bash
kubectl logs -f visitor -n k-23-dark-mode
```
Then, in the first terminal:
```bash
cd ../fix && ./fix.sh
```
Within about half a minute the log flips from ❌ to ✅ (Ctrl+C to stop it):
```
❌ 00:02:20 the site is light, the design team wants dark
✅ 00:02:22 the site is dark
✅ 00:02:24 the site is dark
```
(shortened.) What changed: there is no file to diff this time. The fix is a **new Pod**. `rollout restart` stamps a time into the Pod template, and a changed template makes the Deployment replace its Pods:
```bash
kubectl get deploy theme -n k-23-dark-mode -o jsonpath='{.spec.template.metadata.annotations}{"\n"}'
```
```
{"kubectl.kubernetes.io/restartedAt":"2026-11-09T05:32:19+05:30"}
```
(The time will differ.) The new Pod started *after* the ConfigMap changed, so it copied `dark`.

By hand (this replaces `./fix.sh`, so you don't need to run both):
```bash
kubectl rollout restart deployment/theme -n k-23-dark-mode
kubectl rollout status deployment/theme -n k-23-dark-mode
```

It is a rolling restart: the new Pod must be Ready before the old one goes away, and the old Pod waits a few seconds before stopping (a small `preStop` pause in `break/app.yaml`), so visitors never see a gap. (Deleting the Pod by hand would also work for one Pod, but `rollout restart` is the polite way for a Deployment.)

**Doing this properly, so nobody has to remember.** Two common ways, shown here only so you recognise them; we don't run them:

1. **Put a hash of the config on the Pod template.** When the config changes, the hash changes, the template changes, and the Deployment rolls out new Pods by itself. Helm charts do it like this, and Kustomize does the same with generated ConfigMap names:
   ```yaml
   spec:
     template:
       metadata:
         annotations:
           checksum/config: "<sha256 of the ConfigMap contents>"   # Helm: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
   ```
2. **Mount the ConfigMap as a file** instead of environment variables. Kubernetes updates the mounted files in running Pods after a short delay, without a restart. But be honest about the catch: the **app has to re-read the file** (or watch it). An app that reads its settings once at startup, like ours, would still show the old theme. (Also, a mount that uses `subPath` is never updated.)

## ✅ Verify it yourself
```bash
kubectl get pods -n k-23-dark-mode
```
```
NAME                     READY   STATUS    RESTARTS   AGE
theme-78b9dbb88d-79rjx   1/1     Running   0          16s
visitor                  1/1     Running   0          34s
```
(Names and ages will differ. The old Pod may show `Terminating` for a few seconds first.) The Pod is new (16s, while the visitor is older). Ask it what it sees now:
```bash
kubectl exec deploy/theme -n k-23-dark-mode -- printenv THEME
```
```
dark
```
The visitor's log is green (if you still see a ❌, wait a few seconds and run it again):
```bash
kubectl logs visitor -n k-23-dark-mode --tail=3
```
```
✅ 00:02:30 the site is dark
✅ 00:02:32 the site is dark
✅ 00:02:34 the site is dark
```
Now open the page yourself. In a **second terminal** (leave it running):
```bash
kubectl port-forward -n k-23-dark-mode svc/theme 9223:80
```
```
Forwarding from 127.0.0.1:9223 -> 8080
Forwarding from [::1]:9223 -> 8080
```
On a playground, add `--address 0.0.0.0` and open the URL for port 9223.
Back in the first terminal:
```bash
curl -s localhost:9223/theme
```
```
dark
```
(The port-forward terminal also prints `Handling connection for 9223`.) Or open http://localhost:9223 in your browser: a dark navy "Campus Today" page with a moon and a pink title, instead of the white page with a sun. Press Ctrl+C in the second terminal to stop the port-forward.

## 🎯 Key takeaways
- **A ConfigMap is not a live feed.** Used as environment variables, its values are copied into the container once, when it starts.
- **The proof is in two places:** the ConfigMap (`get cm -o yaml`) says what you *want*; `kubectl exec … -- env` says what the running Pod *has*. When they differ, compare the Pod's age with the time of the change.
- **`kubectl rollout restart deployment/<name>`** gives you new Pods that start with the current config, without downtime.
- **Make it automatic:** a config-hash annotation (Helm, Kustomize) or an app that re-reads a mounted file.

## 💎 Lifelong lesson
> Changing config is not the same as the app reading it.

## 🧹 Clean up
Press Ctrl+C in the port-forward terminal first, then:
```bash
cd .. && ./cleanup.sh
```

## Next →
[K24](../24-showdown-wrong-command/README.md): No crash log. No error from the app. The app never even ran.
