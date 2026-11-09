# D01 · Jupyter blinks… and it's gone

*You click run, Jupyter blinks… and it's gone.*

⏱ 10 min · beginner · Jupyter (`quay.io/jupyter/base-notebook`) · Dockerfile `CMD`, build vs run, PID 1, exit codes, `docker logs`
⬇️ First run downloads about 343 MB (the Jupyter base image). Do it on good Wi-Fi, before the session. Our own image adds only a few KB on top.

## 📖 The story
It's the night before the AI-lab submission at Christ University. Your teammate has packed the lab's Jupyter into a small image with a welcome notebook inside, builds it, hits run, and tells you: *"Docker is broken. Jupyter starts and instantly disappears."* The deadline is at 9 AM. The base image is the same one everybody uses. So what died?

## 🧠 The concept: why, what, how
A container is not a little computer that stays on. It is **one process** wrapped in a box, and that process is called **PID 1**. When PID 1 ends, the container ends. Think of a breakfast cafe: the cafe is open exactly as long as the cook is working. If the cook walks out, the shutters come down.

Two files-and-commands ideas sit underneath:
- A **Dockerfile** is the recipe for an image. `docker build` reads it once and bakes the image. The `CMD` line is written into the image as "what to run when a container starts".
- `docker run` makes a container from that image and starts the `CMD`. So a mistake in `CMD` is baked in at **build** time but only shows up at **run** time.

The cook leaves with a number, the **exit code**:
- `0`: finished normally ("I'm done")
- `1`: crashed with an error
- `127`: "command not found" (the shell was asked for a program that doesn't exist)
- `137`: killed from outside (out of memory, or `docker kill`)

## 🏢 Where you'll meet this at work
- **Kubernetes:** a typo in a pod's `command:` gives `CrashLoopBackOff` (developer, SRE).
- **After an image upgrade:** the new image dropped the old entrypoint script (platform team).
- **CI pipelines:** a job "passes" in 0.1 seconds because the container exited, and nobody read the log (DevOps).

## 💥 Break it
You can do it by hand. Stay in this scenario's folder (`docker/scenarios/01-jupyter-vanishes`) for everything below. Copy the files you will work on into a scratch folder `work/`, build the image from it, and run it:
```bash
cp -R break work && rm work/break.sh
docker build -t d01-jupyter:1.0 work
docker run -d --name d01-jupyter -p 8101:8888 d01-jupyter:1.0
```
Or use the one-line shortcut, which prints every Docker command before it runs it, exactly as above:
```bash
./break/break.sh
```
```
✅ Scenario d01 cleaned up
▶ fresh copy of break/ in work/
▶ $ docker build -t d01-jupyter:1.0 work
... (shortened: Docker's build output) ...
▶ $ docker run -d --name d01-jupyter -p 8101:8888 d01-jupyter:1.0
⏳ Waiting for the container to stop . ✔ ready
```
`work/` is your own copy (git ignores it), so you can edit it freely; the shortcut recreates it fresh every time.

Laptop: try http://localhost:8101. Playground: open the port 8101 URL. Either way, nothing answers. The room sees a clean build and a run that printed a container ID, and no error anywhere.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is it running?** Start with the simplest question, the one you'd ask about any app.
```bash
docker ps --filter name=d01-jupyter
```
```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```
An empty table. (Without `--filter`, other containers on your machine may be listed; ours is missing.)

<details><summary>💡 Hint</summary>
"Not running" doesn't mean "never existed". <code>docker ps</code> shows only the living. Where would a dead container still be listed, and how did it end? Then read what it said and what it was told to run, letter by letter.
</details>

**2. Show me the dead ones too.** `docker ps` hides stopped containers; `-a` shows all.
```bash
docker ps -a --filter name=d01-jupyter
```
```
CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS                       PORTS     NAMES
d18ecb53c434   d01-jupyter:1.0   "tini -g -- start.sh…"   5 seconds ago   Exited (127) 4 seconds ago             d01-jupyter
```
It existed, it ran for a moment, and it left. Read the status: `Exited (127)`. Remember the exit-code list.

**3. Ask for the exit code on its own.** One number, no table to squint at.
```bash
docker inspect -f '{{.State.ExitCode}}' d01-jupyter
```
```
127
```
127 = "command not found".

**4. Read its last words.** The logs say which command was not found.
```bash
docker logs d01-jupyter
```
```
INFO[...] Entered start.sh with args: start-notebok.py --IdentityProvider.token=change-me-123
... (shortened) ...
INFO[...] Executing the command: start-notebok.py --IdentityProvider.token=change-me-123
/usr/local/bin/start.sh: line 249: exec: start-notebok.py: not found
```
The last line is the answer. (The exact wording and line number can differ between image versions.)

**5. What did Docker actually run?** Compare "what Docker ran" with "what I wrote". First, Docker's view: the command stored in the container.
```bash
docker inspect -f '{{json .Config.Cmd}}' d01-jupyter
```
```
["start-notebok.py","--IdentityProvider.token=change-me-123"]
```
Compare that spelling with the one in the error. Look closely at the word.

**6. What did I write?** Now our view: the file we built from. The `CMD` line is the one that produced that list.
```bash
cat work/Dockerfile
```
```
# D01: the AI-lab Jupyter image.
# Start from the Jupyter image we already trust, pinned to one dated tag.
FROM quay.io/jupyter/base-notebook:2026-11-02

# Lets cleanup.sh find (and remove) this image later.
LABEL z2h.scenario=d01

# Put a welcome notebook in the home folder.
COPY --chown=jovyan:users welcome.ipynb /home/jovyan/welcome.ipynb

# What the container runs when it starts.
CMD ["start-notebok.py", "--IdentityProvider.token=change-me-123"]
```
The same spelling is in the file. Docker ran exactly what we wrote.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The program is called `start-notebook.py`. The `CMD` line says `start-notebok.py` (an `o` is missing). `docker build` doesn't check that the program exists, it just stores the words. At `docker run` the shell can't find it, exits with 127, so PID 1 ends and the container ends. Docker did nothing wrong: it faithfully ran the typo.
</details>

## 🔧 Fix it
What changes is one letter in one file. See it first:
```bash
diff break/Dockerfile fix/Dockerfile
```
```
12c12
< CMD ["start-notebok.py", "--IdentityProvider.token=change-me-123"]
---
> CMD ["start-notebook.py", "--IdentityProvider.token=change-me-123"]
```
By hand: open `work/Dockerfile` in any editor (VS Code, nano, Notepad) and add the missing `o` in `CMD`. Or, on macOS/Linux/Git Bash, `sed -i.bak "s/notebok/notebook/" work/Dockerfile && rm work/Dockerfile.bak`. Editing the file changes nothing by itself: the old image still has the typo baked in, and the old container still exists. So: rebuild the image, remove the dead container (its name is taken), run again.
```bash
docker build -t d01-jupyter:1.0 work
docker rm d01-jupyter
docker run -d --name d01-jupyter -p 8101:8888 d01-jupyter:1.0
```
Or run `./fix.sh`, which does the same: it drops the fixed Dockerfile into a fresh `work/`, then prints and runs those exact three commands (the build, the `docker rm`, the run).
```bash
./fix/fix.sh
```
Either way you end in the same place: image `d01-jupyter:1.0`, container `d01-jupyter`.

## ✅ Verify it yourself
```bash
docker ps --filter name=d01-jupyter
```
```
CONTAINER ID   IMAGE             COMMAND                  CREATED          STATUS                    PORTS                                         NAMES
9a24d4cba2a7   d01-jupyter:1.0   "tini -g -- start.sh…"   12 seconds ago   Up 12 seconds (healthy)   0.0.0.0:8101->8888/tcp, [::]:8101->8888/tcp   d01-jupyter
```
(`(healthy)` appears after a few seconds; the base image has a health check.) Open http://localhost:8101/lab?token=change-me-123 (playground: the port 8101 URL + `/lab?token=change-me-123`). JupyterLab opens, and `welcome.ipynb`, the notebook we `COPY`ed in, is in the file list.
```bash
curl -s "http://localhost:8101/api/status?token=change-me-123"
```
```
{"connections": 0, "kernels": 0, "last_activity": "2026-11-09T09:18:36.031392Z", "started": "2026-11-09T09:18:36.031392Z"}
```

## 🎯 Key takeaways
- A Dockerfile's `CMD` is baked in at build time and runs at `docker run`. Build can succeed while run fails.
- A container lives exactly as long as its main process (PID 1).
- `docker ps` shows only the living; `docker ps -a` shows the dead too.
- Exit codes tell the story: `0` done, `1` error, `127` not found, `137` killed.
- Editing a Dockerfile isn't enough: rebuild the image, then recreate the container.

## 💎 Lifelong lesson
> When a container dies, don't stare at the container. Read its last words: `docker logs`.

## 🧹 Clean up
```bash
./cleanup.sh
```
This removes the container, the `d01-jupyter:1.0` image and your `work/` folder.

## Next →
[D02](../02-port-clash/README.md): a port that is already taken.
