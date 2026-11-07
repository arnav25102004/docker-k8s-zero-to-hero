# D05 · One character

*One letter. That's all it takes to break a deploy.*

⏱ 10 min · beginner · IT-Tools (`corentinth/it-tools:2024.10.22-7ca5933`) · image tags, registries, `docker manifest inspect`

⬇️ First run downloads about 24 MB. Quick, but do it before the session anyway.

## 📖 The story
It's the night before the hackathon demo at Christ University. Your teammate says, *"Relax, I remember the version: `2024.10.22-7ca5393`."* He types it from memory, hits Enter at 11:40 pm, and goes to make chai. Ten minutes later the demo page still doesn't open. The code is fine. The laptop is fine. Something about one tiny string isn't.

## 🧠 The concept: why, what, how
Every image has an address: **`registry / repository : tag`**, for example `docker.io / corentinth/it-tools : 2024.10.22-7ca5933`. When you run it, Docker goes to the registry (Docker Hub by default) and asks for exactly that tag.

Think of a train ticket: the station (registry), the train (repository) and the coach seat (tag). Swap two digits in the seat number and the seat simply doesn't exist, even though the train is real.

- A **tag** is just a label somebody put on an image. Docker never guesses, never "finds the closest one".
- If the label isn't in the registry, the answer is `not found` (older Docker: `manifest unknown`).
- `latest` is not magic either. It is only a tag that people *agree* to move. Leave the tag off and Docker quietly asks for `latest`.
- Pinning an exact tag (like `2024.10.22-7ca5933`) means everyone runs the same thing. It also means you must get it exactly right.

## 🏢 Where you'll meet this at work
- **A failed deploy from a mistyped or deleted tag**: the pipeline is green until the very last step (developer, SRE).
- **A private registry you aren't logged in to**: Docker prints the same family of "not found" errors (platform team).
- **Kubernetes `ErrImagePull` / `ImagePullBackOff`**: same cause, different name, on a cluster (SRE).

## 💥 Break it
```bash
cd break && ./break.sh
```
Docker prints an error and returns to the prompt, and nothing is running. Laptop: open http://localhost:8105. Playground: open the port 8105 URL. The browser says the site **can't be reached**.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Read the error. All of it.**
It is already on your screen from `break.sh`. This is the part that matters:
```
Unable to find image 'corentinth/it-tools:2024.10.22-7ca5393' locally
docker: Error response from daemon: failed to resolve reference "docker.io/corentinth/it-tools:2024.10.22-7ca5393": docker.io/corentinth/it-tools:2024.10.22-7ca5393: not found
```
Docker looked locally, then asked the registry. The registry said **not found**.

<details><summary>💡 Hint</summary>
Docker names the thing it could not find, in full. Is that exactly the version your teammate meant to type? Compare it character by character with the tag in the story.
</details>

**2. Did a container get created anyway?**
```bash
docker ps -a --filter name=d05
```
```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```
Only the header row. No container, not even a stopped one: Docker could not even *start* creating it without an image. (Plain `docker ps -a` also works. Look for a `d05-tools` row: there isn't one.)

**3. Ask the registry directly: does this tag exist?**
```bash
docker manifest inspect corentinth/it-tools:2024.10.22-7ca5393
```
```
no such manifest: docker.io/corentinth/it-tools:2024.10.22-7ca5393
```
A "manifest" is the registry's description of an image. No manifest, no image.

**4. Compare with the tag from the course notes.**
```bash
docker manifest inspect corentinth/it-tools:2024.10.22-7ca5933 | head -8
```
```
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.oci.image.index.v1+json",
   "manifests": [
      {
         "mediaType": "application/vnd.oci.image.manifest.v1+json",
         "size": 2189,
         "digest": "sha256:6f177c156b9466610e0f2093e24668b78da501c66f0054f98bccb582b74ab26b",
```
(shortened.) This one exists. Put the two tags side by side: `7ca5393` and `7ca5933`. Two characters swapped.

**5. Browse what the registry really has.**
```bash
curl -s 'https://hub.docker.com/v2/repositories/corentinth/it-tools/tags?page_size=5&name=7ca59' | grep -o '"name":"[^"]*"'
```
```
"name":"2024.10.22-7ca5933"
```
(Or open https://hub.docker.com/r/corentinth/it-tools/tags in the browser.) Only the real tag is listed. `...7ca5393` was never published.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The tag `2024.10.22-7ca5393` does not exist in the registry: two characters of the commit hash were swapped (`7ca5933` is the real one). Docker can't start a container from an image it can't find, so it printed the error and created nothing.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: the tag on the `docker run` line, nothing else. The two lines side by side (`break.sh` first, `fix.sh` second):
```bash
grep -h -o -e '^docker run.*-p 8105:80 [^ ]*' ../break/break.sh fix.sh
```
```
docker run -d --name d05-tools --label z2h.scenario=d05 -p 8105:80 corentinth/it-tools:2024.10.22-7ca5393
docker run -d --name d05-tools --label z2h.scenario=d05 -p 8105:80 corentinth/it-tools:2024.10.22-7ca5933
```
(The `--label` is only there so `cleanup.sh` can find the container.) By hand, just run it again with the correct tag, **copy-pasted**:
```bash
docker run -d --name d05-tools -p 8105:80 corentinth/it-tools:2024.10.22-7ca5933
```

## ✅ Verify it yourself
Open http://localhost:8105 (playground: the port 8105 URL). IT-Tools opens. Then:
```bash
docker ps --filter name=d05
```
```
CONTAINER ID   IMAGE                                    COMMAND                  CREATED         STATUS         PORTS                                     NAMES
5d170a40c9db   corentinth/it-tools:2024.10.22-7ca5933   "/docker-entrypoint.…"   1 second ago    Up 1 second    0.0.0.0:8105->80/tcp, [::]:8105->80/tcp   d05-tools
```
(Your ID and times will differ.)
```bash
docker image ls corentinth/it-tools
```
```
IMAGE                                    ID             DISK USAGE   CONTENT SIZE   EXTRA
corentinth/it-tools:2024.10.22-7ca5933   8b8128748339       88.6MB         23.6MB   U
```
(shortened: you may also see a `latest` row from other lessons.) The image now exists locally, under exactly the tag we asked for.

## 🎯 Key takeaways
- An image reference is `registry/repository:tag`, and the tag must exist in the registry.
- `not found` / `manifest unknown` means the registry has no such tag. Check spelling before anything else.
- `docker manifest inspect IMAGE:TAG` is a quick "does this exist?" test, without downloading.
- If the image can't be pulled, no container is created at all, so `docker ps -a` is empty.

## 💎 Lifelong lesson
> Copy-paste versions. Never type them from memory.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
D06: Jupyter is training your AI model, then dies without a word. Docker killed it for using too much memory.
