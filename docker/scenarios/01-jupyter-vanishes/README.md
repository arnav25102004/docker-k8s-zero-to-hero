# D01 · Jupyter blinks… and it's gone

*You click run, Jupyter blinks… and it's gone.*

⏱ 10 min · beginner · Jupyter (`quay.io/jupyter/base-notebook`) · PID 1, exit codes, `docker logs`
⬇️ First run downloads about 343 MB. Do it on good Wi-Fi, before the session.

## 📖 The story
It's the night before the AI-lab submission at Christ University. Your teammate pastes a "new, faster" run command from a WhatsApp group, hits Enter, and tells you: *"Docker is broken. Jupyter starts and instantly disappears."* The deadline is at 9 AM. Nobody has changed the image. So what died?

## 🧠 The concept: why, what, how
A container is not a little computer that stays on. It is **one process** wrapped in a box, and that process is called **PID 1**. When PID 1 ends, the container ends. Think of a breakfast cafe: the cafe is open exactly as long as the cook is working. If the cook walks out, the shutters come down.

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
```bash
cd break && ./break.sh
```
Laptop: try http://localhost:8101. Playground: open the port 8101 URL. Either way, nothing answers.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is it running?**
```bash
docker ps
```
Look for `d01-jupyter`. It isn't there. (Other containers on your machine may be listed; ours is missing.) "Not running" doesn't mean "never existed".

**2. Show me the dead ones too.**
```bash
docker ps -a --filter name=d01-jupyter
```
```
CONTAINER ID   IMAGE                                      COMMAND                  CREATED        STATUS                     NAMES
f3136eaa82a0   quay.io/jupyter/base-notebook:2026-11-02   "tini -g -- start.sh…"   1 second ago   Exited (127) ...           d01-jupyter
```
Read the status: `Exited (127)`. Remember the exit-code list.

**3. Read its last words.**
```bash
docker logs d01-jupyter
```
```
INFO[...] Executing the command: start-notebok.py --IdentityProvider.token=change-me-123
/usr/local/bin/start.sh: line 249: exec: start-notebok.py: not found
```
The last line is the answer.

**4. What command did we actually give it?**
```bash
docker inspect -f '{{.Config.Cmd}}' d01-jupyter
```
```
[start-notebok.py --IdentityProvider.token=change-me-123]
```
Compare that spelling with the one in the error. Look closely at the word.

<details><summary>💡 Hint</summary>
Exit code 127 means "command not found". Read the program name one letter at a time.
</details>

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The program is called `start-notebook.py`. The command says `start-notebok.py` (an `o` is missing). The shell can't find it, exits with 127, so PID 1 ends and the container ends. Docker did nothing wrong.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: one letter, nothing else. See the two `docker run` lines side by side:
```bash
grep -h 'IMAGE" start' ../break/break.sh
grep -h 'IMAGE" start' fix.sh
```
```
  "$IMAGE" start-notebok.py --IdentityProvider.token=change-me-123 >/dev/null \
  "$IMAGE" start-notebook.py --IdentityProvider.token=change-me-123 >/dev/null \
```
(`break.sh` first, `fix.sh` second: `notebok` became `notebook`.)

By hand: `docker rm -f d01-jupyter`, then run it again with the correct name:
```bash
docker run -d --name d01-jupyter -p 8101:8888 \
  quay.io/jupyter/base-notebook:2026-11-02 start-notebook.py --IdentityProvider.token=change-me-123
```

## ✅ Verify it yourself
```bash
docker ps
```
```
... quay.io/jupyter/base-notebook:2026-11-02   "tini -g -- start.sh…"   ...   Up ...   0.0.0.0:8101->8888/tcp ...   d01-jupyter
```
Open http://localhost:8101/lab?token=change-me-123 (playground: the port 8101 URL + `/lab?token=change-me-123`). JupyterLab opens.
```bash
curl "http://localhost:8101/api/status?token=change-me-123"
```
```
{"connections": 0, "kernels": 0, "last_activity": "...", "started": "..."}
```

## 🎯 Key takeaways
- A container lives exactly as long as its main process (PID 1).
- `docker ps` shows only the living; `docker ps -a` shows the dead too.
- Exit codes tell the story: `0` done, `1` error, `127` not found, `137` killed.
- Typos in `command:` are the cheapest outage in the world, and the cheapest to fix.

## 💎 Lifelong lesson
> When a container dies, don't stare at the container. Read its last words: `docker logs`.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
D02: a port that is already taken.
