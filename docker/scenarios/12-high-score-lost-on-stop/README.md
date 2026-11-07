# D12 · The high score that vanished

*You beat the high score. The server restarts. Your name is gone.*

⏱ 15 min · beginner · "Dosa Dash", a tiny original browser game with a high-score server (Python standard library only) · `docker stop`, PID 1, SIGTERM vs SIGKILL, shell form vs exec form

⬇️ First run downloads about 19 MB (the `python:3.12-alpine` base image), plus about 2 MB (`busybox:1.36`) the first time you peek inside the volume. Do it on good Wi-Fi, before the session. The game is one file and needs no internet.

## 📖 The story
Friday night at the college fest. The canteen team built **Dosa Dash**: catch the falling dosas on a tawa, and the top five go on a big screen. Lakshmi beats everyone with 42 points, then Ravi, then Meera. Then the organisers push a "tiny update" and restart the server. The big screen shows an empty table. *"Where did Lakshmi go?"* The server is healthy. The code that saves the scores is right there. It just never ran.

## 🧠 The concept: why, what, how
When you type `docker stop`, Docker does **not** pull the plug. It politely knocks first: it sends a signal called **SIGTERM** ("please finish up and leave") to **PID 1**, the first process inside the container. It waits (10 s in our commands, `-t 10`). If the process is still there, Docker sends **SIGKILL**, which cannot be caught: instant end, no goodbye.

Our game server catches SIGTERM and **saves the scores to `/data/scores.json`** before leaving. That is the graceful goodbye.

The trap is **who PID 1 is**. Think of a hotel: you ring the *front desk* to tell the guest to leave.
- **Shell form** `CMD python server.py | tee …` makes Docker run `/bin/sh -c "…"`. The shell becomes PID 1, Python is only its child, and the shell does not pass the message on. The desk takes the note and puts it in a drawer.
- **Exec form** `CMD ["python", "server.py"]` makes Python itself PID 1. The message goes straight to the guest.

```
docker stop ──SIGTERM──▶ PID 1 = sh ─ ✖ ignores it ─▶ (10 s later) SIGKILL ─▶ scores lost
docker stop ──SIGTERM──▶ PID 1 = python ─▶ saves scores ─▶ exits 0 in a blink
```

## 🏢 Where you'll meet this at work
- **Rolling deploys**: every Pod that ignores SIGTERM makes Kubernetes wait the full 30 s before killing it. Fifty Pods, fifty slow goodbyes (platform team, SRE).
- **Lost work**: in-flight requests dropped, database connections never closed, a queue worker's half-finished job gone (developer).
- **Wrapper scripts and shell-form `CMD`**: the usual cause. The usual cures: exec form, `exec python …` at the end of an entrypoint script, or a tiny init such as `docker run --init` / `tini` (developer, SRE).

## 💥 Break it
```bash
cd break && ./break.sh
```
The script plays three fest scores (Lakshmi 42, Ravi 35, Meera 28), then "deploys": it stops the server (about 10 seconds of waiting) and starts it again. The room should see the script finish happily. Now open http://localhost:8112 (playground: the port 8112 URL): the **Top 5** table says *No scores yet. Be the first!* Nothing in the script printed an error.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Ask the server what it remembers.**
```bash
curl -s localhost:8112/api/scores
```
```
[]
```
An empty list. Three players were on the board a minute ago.

<details><summary>💡 Hint</summary>
The server is meant to <em>save</em> the scores when it is asked to stop. Did the stop go the way you'd expect? How long did it take, and how did the container end?
</details>

**2. Time the stop.** (`time` prints a summary line; its format depends on your shell. Look at the total.)
```bash
time docker stop -t 10 d12-game
```
```
d12-game
docker stop -t 10 d12-game  0.01s user 0.01s system 0% cpu 10.146 total
```
About **10 seconds** for a tiny game server. A polite goodbye takes a blink. Docker waited the whole `-t 10` and then lost patience.

**3. How did it end?** Exit code 137 = 128 + 9, which means *killed by signal 9 (SIGKILL)*:
```bash
docker inspect -f '{{.State.ExitCode}}' d12-game
```
```
137
```
A clean exit would be `0`.

**4. What did the server log?**
```bash
docker logs d12-game
```
```
📂 no saved scores yet, starting with an empty board
🥞 Dosa Dash is serving on port 8000
🏆 new score: Lakshmi scored 42
🏆 new score: Ravi scored 35
🏆 new score: Meera scored 28
📂 no saved scores yet, starting with an empty board
🥞 Dosa Dash is serving on port 8000
```
Three scores arrive, and then the log jumps straight to a fresh start. The line `💾 saved N scores` never appears: the save code never ran.

**5. Who is PID 1?** Start the container again (step 2 stopped it), then list its processes:
```bash
docker start d12-game
docker exec d12-game ps
```
```
d12-game
PID   USER     TIME  COMMAND
    1 root      0:00 /bin/sh -c python server.py | tee /data/server.log
    7 root      0:00 python server.py
    8 root      0:00 tee /data/server.log
    9 root      0:00 ps
```
PID 1 is **`/bin/sh`**, not Python. Python is PID 7, a child of the shell. (`ps` is listing itself too; ignore that last line.)

**6. Where did that shell come from?**
```bash
docker inspect -f '{{json .Config.Cmd}}' d12-game
```
```
["/bin/sh","-c","python server.py | tee /data/server.log"]
```
We wrote `CMD python server.py | tee …` (shell form), so Docker wrapped it in `/bin/sh -c`. And the file the save should have created is not in the volume either:
```bash
docker run --rm -v d12-data:/data busybox:1.36 ls /data
```
```
server.log
```
Only the log. No `scores.json`.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The shell-form `CMD` made `/bin/sh` PID 1. `docker stop` sent SIGTERM to the shell, and the shell did not forward it to Python (a shell running as PID 1 simply ignores it). Python never heard the goodbye, so the save-on-SIGTERM code never ran. After 10 seconds Docker sent SIGKILL (exit code 137) and the scores, which lived only in memory, vanished.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: `break/` and `fix/` hold the same game and the same `server.py`. Only the `Dockerfile` differs:
```bash
grep -n '^CMD' ../break/Dockerfile Dockerfile
```
```
../break/Dockerfile:9:CMD python server.py | tee /data/server.log
Dockerfile:8:CMD ["python", "server.py"]
```
Exec form (a JSON list) makes Python PID 1. We also dropped the `| tee`: the server already prints its own log lines, and `docker logs` shows them. By hand, this replaces `./fix.sh`: remove the old container, rebuild from the fixed `Dockerfile`, run again (the volume `d12-data` keeps its data):
```bash
docker rm -f d12-game
docker build -t d12-game:1.0 .
docker run -d --name d12-game -p 8112:8000 -v d12-data:/data d12-game:1.0
```

## ✅ Verify it yourself
Run these in order, right after the fix:
```bash
docker exec d12-game ps
```
```
PID   USER     TIME  COMMAND
    1 root      0:00 python server.py
    8 root      0:00 ps
```
Python is PID 1 now. Play a round at http://localhost:8112 (playground: the port 8112 URL) and save your name, or post a score by hand:
```bash
curl -s -X POST -H 'Content-Type: application/json' -d '{"name":"Priya","score":57}' localhost:8112/api/scores
curl -s localhost:8112/api/scores
```
```
{}
[{"name": "Priya", "score": 57}]
```
Now the moment of truth: stop the server, look at how it ended, and read its goodbye.
```bash
time docker stop -t 10 d12-game
docker inspect -f '{{.State.ExitCode}}' d12-game
docker logs d12-game | tail -2
```
```
d12-game
docker stop -t 10 d12-game  0.01s user 0.01s system 13% cpu 0.117 total
0
🏆 new score: Priya scored 57
💾 saved 1 scores to /data/scores.json
```
A fraction of a second, exit code `0`, and a `💾 saved` line. Start it again; the score is still there:
```bash
docker start d12-game
sleep 2
curl -s localhost:8112/api/scores
```
```
d12-game
[{"name": "Priya", "score": 57}]
```
Refresh the page: Priya is on the board. 🎉

## 🎯 Key takeaways
- `docker stop` = SIGTERM to **PID 1**, a wait (`-t`), then SIGKILL. Exit code `137` means it was killed.
- Shell-form `CMD` runs your app under `/bin/sh -c`: the shell is PID 1 and your app never hears SIGTERM.
- Exec-form `CMD ["python", "server.py"]` makes your app PID 1, so it can save its work and exit in a blink.
- Check with `docker exec <name> ps` and `docker inspect -f '{{json .Config.Cmd}}'`. `docker run --init` is a safety net, not a substitute for handling SIGTERM.

## 💎 Lifelong lesson
> Graceful shutdown is a feature. Design for the goodbye.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
D13: The portfolio disappears. The website is in the image. You can prove it. And it's gone.
