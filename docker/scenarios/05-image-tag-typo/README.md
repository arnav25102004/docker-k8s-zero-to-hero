# D05 · One character

*One letter. That's all it takes to break a deploy.*

⏱ 10 min · beginner · IT-Tools (`corentinth/it-tools`) wrapped in a tiny Dockerfile of our own · `FROM`, image tags, `docker build`, `docker manifest inspect`

⬇️ First run downloads about 24 MB (the IT-Tools image, see [IMAGES.md](../IMAGES.md)). Quick, but do it before the session anyway.

## 📖 The story
It's the night before the hackathon demo at Christ University. The team wants IT-Tools on a laptop, with a small "Campus IT-Tools is live" page of their own next to it. Ravi has written the Dockerfile: *"Relax, I know the version."* He hits Enter at 11:40 pm and goes to make chai. Ten minutes later the demo page still doesn't open. The code is fine. The laptop is fine. Something in the Dockerfile isn't.

## 🧠 The concept: why, what, how
Every image has an address: **`registry / repository : tag`**, for example `docker.io / corentinth / it-tools : <tag>`. A Dockerfile starts with **`FROM`**: "begin with this image". Before it does anything else, `docker build` goes to the registry (Docker Hub by default) and asks for exactly that tag.

Think of a train ticket: the station (registry), the train (repository) and the seat (tag). The seat has to exist on that train.

- A **tag** is just a label somebody put on an image. Docker never guesses and never "finds the closest one".
- If the label isn't in the registry, the answer is `not found` (older Docker: `manifest unknown`).
- `latest` is not magic either: it is only a tag that people *agree* to move. Leave the tag off and Docker quietly asks for `latest`.
- Pinning an exact tag means everyone runs the same thing. It also means the tag must be exactly right.
- Our Dockerfile adds two small things on top of IT-Tools: a `LABEL` (a name tag stuck on the image) and a `COPY` of our own `hello.html` into the folder nginx serves. That is the whole reason it exists.

## 🏢 Where you'll meet this at work
- **A failed CI build from a wrong or deleted tag**: the pipeline is green until the very first `FROM` (developer, SRE).
- **A private registry you aren't logged in to**: Docker prints the same family of "not found" errors (platform team).
- **Kubernetes `ErrImagePull` / `ImagePullBackOff`**: same cause, different name, on a cluster (SRE).

## 💥 Break it
Every command in this README runs from the scenario folder (the one holding `break/`, `fix/` and this file). You get a folder with a `Dockerfile` and `hello.html`. Make your own working copy and build it, exactly like Ravi did (`./cleanup.sh` first is safe at any time and makes a repeat run start clean):
```bash
./cleanup.sh
rm -rf work && cp -R break work
docker build -t d05-tools:1.0 work
```
Or the one-line shortcut, which makes `work/` for you and prints every Docker command it runs (you stay in the scenario folder):
```bash
./break/break.sh
```
(Git Bash on Windows: the scripts set `MSYS_NO_PATHCONV=1` for you; if you type Docker commands with paths yourself, set it first.) `docker build` prints an error and returns to the prompt. Nothing is running, so there is nothing to open on http://localhost:8105 (playground: the port 8105 URL).

## 🔍 Investigate
Guess first, then run these **in order**. Run them from the scenario folder, the same place you ran `./break/break.sh`.

**1. Read the error. All of it.**
It is already on your screen from the build. This is the part that matters (shortened; the exact wording varies by Docker version and engine, and the last `View build details` line only appears on Docker Desktop):
```
#2 [internal] load metadata for docker.io/corentinth/it-tools:2024.10.22-7ca5393
#2 ERROR: docker.io/corentinth/it-tools:2024.10.22-7ca5393: not found
...
Dockerfile:2
--------------------
   1 |     # Campus IT-Tools: the course's IT-Tools image plus a small welcome page.
   2 | >>> FROM corentinth/it-tools:2024.10.22-7ca5393
   3 |     
   4 |     # Who owns this image (also lets cleanup.sh find it).
--------------------
ERROR: failed to build: failed to solve: corentinth/it-tools:2024.10.22-7ca5393: failed to resolve source metadata for docker.io/corentinth/it-tools:2024.10.22-7ca5393: docker.io/corentinth/it-tools:2024.10.22-7ca5393: not found
```
Docker points at the exact Dockerfile line (`>>>`), and the registry said **not found**. (On an older Docker you may see `pull access denied` or `manifest unknown` instead. The idea is the same.)

<details><summary>💡 Hint</summary>
Docker names the thing it could not find, in full, and shows the line of your Dockerfile that asked for it. Is that tag really published in the registry? How could you check, without building anything?
</details>

**2. Did Docker make anything at all?** A failed build should leave nothing behind, so confirm it.
```bash
docker ps -a --filter name=d05
docker image ls d05-tools
```
```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
IMAGE   ID             DISK USAGE   CONTENT SIZE   EXTRA
```
Only header rows (the `image ls` columns differ by Docker version; older ones show `REPOSITORY TAG IMAGE ID CREATED SIZE`). No container, and no `d05-tools` image: the build stopped at the very first line, so no later line (`LABEL`, `COPY`) ever ran.

**3. Ask the registry directly: does this tag exist?** Use the tag from the error, with no build around it.
```bash
docker manifest inspect corentinth/it-tools:2024.10.22-7ca5393
```
```
no such manifest: docker.io/corentinth/it-tools:2024.10.22-7ca5393
```
A "manifest" is the registry's description of an image. No manifest, no image. (`docker manifest` may need Docker 20.10+ or "experimental" switched on in very old setups.)

**4. Now read what you wrote.** Compare the file with what the registry told you.
```bash
cat work/Dockerfile
```
```
# Campus IT-Tools: the course's IT-Tools image plus a small welcome page.
FROM corentinth/it-tools:2024.10.22-7ca5393

# Who owns this image (also lets cleanup.sh find it).
LABEL z2h.scenario=d05
LABEL org.opencontainers.image.title="Campus IT-Tools"

# nginx serves everything in this folder, so hello.html appears at /hello.html
COPY hello.html /usr/share/nginx/html/hello.html
```
The `FROM` line is the one Docker complained about, character for character.

**5. Browse what the registry really has.** Search for tags that start like ours.
```bash
curl -s 'https://hub.docker.com/v2/repositories/corentinth/it-tools/tags?page_size=5&name=7ca59' | grep -o '"name":"[^"]*"'
```
```
"name":"2024.10.22-7ca5933"
```
(Or open https://hub.docker.com/r/corentinth/it-tools/tags in the browser.) Put the two tags side by side: `7ca5393` in the Dockerfile, `7ca5933` in the registry. Only the second was ever published.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The tag `2024.10.22-7ca5393` does not exist in the registry: two characters of the commit hash were swapped (`7ca5933` is the real one). `FROM` is the first line of the Dockerfile, so `docker build` failed there, before `LABEL`, before `COPY`, and long before any container could run.
</details>

## 🔧 Fix it
What changed between the two folders: one line in the `Dockerfile`, nothing else.
```bash
diff break/Dockerfile fix/Dockerfile
```
```
2c2
< FROM corentinth/it-tools:2024.10.22-7ca5393
---
> FROM corentinth/it-tools:2024.10.22-7ca5933
```
By hand: open `work/Dockerfile` in your editor and put the correct tag in, **copy-pasted** from the Docker Hub list (not retyped). Check the line, then build and run:
```bash
grep -n FROM work/Dockerfile
docker build -t d05-tools:1.0 work
docker rm -f d05-tools
docker run -d --name d05-tools -p 8105:80 d05-tools:1.0
```
```
2:FROM corentinth/it-tools:2024.10.22-7ca5933
```
(The build output is a few dozen lines ending in `naming to docker.io/library/d05-tools:1.0 done`. `docker rm -f` prints nothing when there is no container yet; it just makes the run safe to repeat.)

Or run `./fix/fix.sh`, which does the same: it makes a fresh `work/` from `fix/`, then runs those build and run commands, printing each one.
```bash
./fix/fix.sh
```

## ✅ Verify it yourself
Open http://localhost:8105 (playground: the port 8105 URL): IT-Tools opens. Then:
```bash
docker ps --filter name=d05-tools
```
```
CONTAINER ID   IMAGE           COMMAND                  CREATED         STATUS         PORTS                                     NAMES
8ebffd72b364   d05-tools:1.0   "/docker-entrypoint.…"   6 seconds ago   Up 5 seconds   0.0.0.0:8105->80/tcp, [::]:8105->80/tcp   d05-tools
```
(Your ID and times will differ.) Now the two things our own Dockerfile added. Your page, copied into the image:
```bash
curl -s localhost:8105/hello.html | grep h1
```
```
  <h1>Campus IT-Tools is live</h1>
```
(Or open http://localhost:8105/hello.html.) And the label stuck on the image:
```bash
docker image inspect -f '{{json .Config.Labels}}' d05-tools:1.0
```
```
{"maintainer":"NGINX Docker Maintainers <docker-maint@nginx.com>","org.opencontainers.image.title":"Campus IT-Tools","z2h.scenario":"d05"}
```
Our two labels sit next to one the base image already had. A Dockerfile that starts with `FROM` keeps everything the base image brought with it.

## 🎯 Key takeaways
- An image reference is `registry/repository:tag`, and the tag must exist in the registry.
- `FROM` is the first thing `docker build` resolves. If it fails, nothing after it runs and no image is made.
- `not found` / `manifest unknown` means the registry has no such tag. Check spelling before anything else.
- `docker manifest inspect IMAGE:TAG` is a quick "does this exist?" test, without downloading.

## 💎 Lifelong lesson
> Copy-paste versions. Never type them from memory.

## 🧹 Clean up
```bash
./cleanup.sh
```
(It removes the container, the `d05-tools` image and `work/`.)

## Next →
[D06](../06-ai-trainer-oom-killed/README.md): *Your AI model was a few epochs into training. Then it vanished. No error. No goodbye.*
