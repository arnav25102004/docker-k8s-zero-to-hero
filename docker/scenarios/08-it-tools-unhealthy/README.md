# D08 · Healthy app, sick label

*The app works perfectly. Docker swears it's sick.*

⏱ 10 min · beginner · IT-Tools (`corentinth/it-tools`) with a `HEALTHCHECK` in our own Dockerfile · `HEALTHCHECK`, `docker inspect`

⬇️ First run downloads about 24 MB (the IT-Tools image, see [IMAGES.md](../IMAGES.md)). Do it on good Wi-Fi, before the session. If you already did D02, D05 or D09, it's cached.

All commands below run from this scenario folder (`docker/scenarios/08-it-tools-unhealthy`).

## 📖 The story
It's the night before the campus fest registration opens. Your team's tools page runs in a container, and the monitoring dashboard has just turned red: **unhealthy**. Someone opens the page in a browser. It loads instantly and works. *"The monitor is broken!"* says one friend. *"The app is broken!"* says another. Who is right?

## 🧠 The concept: why, what, how
Docker cannot see inside your app, so it asks. A **health check** is a small command that Docker runs *inside the container* every few seconds. Exit code `0` means "all good"; anything else is a strike. After enough strikes in a row, Docker labels the container `unhealthy`.

Think of the **floor manager** of a hotel who knocks on a guest's door every few minutes: "Everything okay in there?" If nobody answers, the manager writes "guest missing" in the register.

- You write the health check yourself, in the Dockerfile, with the `HEALTHCHECK` instruction. It sets the command, how often (`--interval`) and how many strikes in a row are allowed (`--retries`).
- `unhealthy` is a verdict about **the check**, not proof about **the app**.
- The check is code too, and code has bugs.

## 🏢 Where you'll meet this at work
- **Load balancers** that stop sending traffic to servers that fail their health check (SRE, platform team).
- **Docker Compose `depends_on: condition: service_healthy`**, where one service waits for another to be healthy before it starts (developer).
- **Kubernetes liveness and readiness probes**, the same idea at cluster scale. A wrong readiness probe keeps a healthy app from ever getting visitors ([K06](../../../kubernetes/scenarios/06-kanboard-never-ready/README.md)), and an impatient liveness probe restarts a perfectly good app forever ([K07](../../../kubernetes/scenarios/07-showdown-slow-start/README.md)).

## 💥 Break it
You get a folder `break/` with one file, the `Dockerfile`. Make your own working copy, build it and run it, exactly like the team did. (If `work/` already exists from an earlier try, delete it first with `rm -rf work`.)
```bash
cp -R break work
docker build -t d08-tools:1.0 work
docker run -d --name d08-tools -p 8108:80 d08-tools:1.0
```
Or the one-line shortcut, which prints every Docker command it runs:
```bash
./break/break.sh
```
(Git Bash on Windows: the scripts set `MSYS_NO_PATHCONV=1` for you; if you type Docker commands with paths yourself, set it first.)

Laptop: http://localhost:8108 shows IT-Tools. Playground: open the port 8108 URL. Docker needs a few failed checks before it gives its verdict, so wait about 10 seconds. (The script waits for you.)

## 🔍 Investigate
Guess first, then run these **in order**.

**1. What does Docker say?**
```bash
docker ps --filter name=d08-tools
```
```
CONTAINER ID   IMAGE           COMMAND                  CREATED          STATUS                      PORTS                                     NAMES
59bc47dca80a   d08-tools:1.0   "/docker-entrypoint.…"   14 seconds ago   Up 13 seconds (unhealthy)   0.0.0.0:8108->80/tcp, [::]:8108->80/tcp   d08-tools
```
`Up` means the container is running, but the status ends with **(unhealthy)**. (Your container ID and times will differ.)

**2. Is the app really broken?** Ask it directly, from outside:
```bash
curl -sI localhost:8108 | head -1
```
```
HTTP/1.1 200 OK
```
Open http://localhost:8108 too. The app is fine! So Docker says "sick" and the app says "fine". One of them is wrong.

<details><summary>💡 Hint</summary>
The health check is a command Docker runs <i>inside</i> the container. Instead of trusting the label, read the command. What address does it call? And on which port does the app actually listen?
</details>

**3. What did the health check see?** Docker keeps a diary of every check:
```bash
docker inspect -f '{{json .State.Health}}' d08-tools
```
```
{"Status":"unhealthy","FailingStreak":6,"Log":[{"Start":"2026-11-09T10:05:52.805649219Z","End":"2026-11-09T10:05:52.851490803Z","ExitCode":1,"Output":"wget: can't connect to remote host (127.0.0.1): Connection refused\n"}, … (shortened: 4 more entries just like this one)]}
```
(Your times will differ; Docker keeps the last 5 entries.) Read the `Output`: *"Connection refused."* Nobody answered the knock. `FailingStreak` counts the strikes in a row, and it keeps climbing every 3 seconds.

**4. What exactly is the check?** Compare it with what we wrote. This is the file you built from:
```bash
cat work/Dockerfile
```
```
# Campus tools page: the course's IT-Tools image plus a health check of our own.
FROM corentinth/it-tools:2024.10.22-7ca5933

# Who owns this image (also lets cleanup.sh find it).
LABEL z2h.scenario=d08

# Every 3 seconds Docker runs this command INSIDE the container.
# Exit code 0 = healthy. Two failures in a row = the container is marked unhealthy.
HEALTHCHECK --interval=3s --timeout=2s --retries=2 \
  CMD wget -qO- http://127.0.0.1:8080/ || exit 1
```
The check calls `http://127.0.0.1:8080/` with `wget` (the probe tool IT-Tools' Alpine image ships with). It runs every 3 seconds, and 2 failures in a row means unhealthy. That is why the verdict takes about `interval × retries` = 6 seconds, plus the time the first check waits.

**5. Test the test.** Run the very same command by hand, inside the container, on the port in the check and then on port 80 (the port Docker publishes as 8108):
```bash
docker exec d08-tools sh -c 'wget -qO- http://127.0.0.1:8080/ >/dev/null; echo "exit=$?"'
docker exec d08-tools sh -c 'wget -qO- http://127.0.0.1:80/ >/dev/null; echo "exit=$?"'
```
```
exit=1
wget: can't connect to remote host (127.0.0.1): Connection refused
exit=0
```
Port 8080 fails (exit 1), port 80 works (exit 0). (The error line may print before or after `exit=1`.)

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The `HEALTHCHECK` in the Dockerfile probes port **8080**, but IT-Tools listens on port **80**. The check fails every time, so Docker reports `unhealthy`. The app was never sick; the check was knocking on the wrong door.
</details>

## 🔧 Fix it
What changed between the two folders: one line in the `Dockerfile`, nothing else.
```bash
diff break/Dockerfile fix/Dockerfile
```
```
10c10
<   CMD wget -qO- http://127.0.0.1:8080/ || exit 1
---
>   CMD wget -qO- http://127.0.0.1:80/ || exit 1
```
By hand: open `work/Dockerfile` in your editor and change `8080` to `80`. Check the line, then rebuild and recreate the container (a running container's health check comes from its image, so it needs a new image and a new container):
```bash
grep -n -A1 HEALTHCHECK work/Dockerfile
docker build -t d08-tools:1.0 work
docker rm -f d08-tools
docker run -d --name d08-tools -p 8108:80 d08-tools:1.0
```
```
9:HEALTHCHECK --interval=3s --timeout=2s --retries=2 \
10-  CMD wget -qO- http://127.0.0.1:80/ || exit 1
```
(The build prints a few dozen lines. `docker rm -f` prints the container name, then `docker run` prints the new container ID.)

Or run the shortcut, which does the same: it makes a fresh `work/` from `fix/`, then runs those commands, printing each one.
```bash
./fix/fix.sh
```

## ✅ Verify it yourself
```bash
docker ps --filter name=d08-tools
```
```
CONTAINER ID   IMAGE           COMMAND                  CREATED          STATUS                    PORTS                                     NAMES
ac194cb9bd02   d08-tools:1.0   "/docker-entrypoint.…"   13 seconds ago   Up 12 seconds (healthy)   0.0.0.0:8108->80/tcp, [::]:8108->80/tcp   d08-tools
```
`(healthy)` now. (Right after the fix it may briefly say `(health: starting)`; the first check runs after 3 seconds, so run it again.)
```bash
docker inspect -f '{{.State.Health.Status}}' d08-tools
docker inspect -f '{{json .Config.Healthcheck}}' d08-tools
curl -sI localhost:8108 | head -1
```
```
healthy
{"Test":["CMD-SHELL","wget -qO- http://127.0.0.1:80/ || exit 1"],"Interval":3000000000,"Timeout":2000000000,"Retries":2}
HTTP/1.1 200 OK
```
(`Interval` and `Timeout` are in nanoseconds.) Open http://localhost:8108 again. Playground: the port 8108 URL. Same app as before; only the label changed.

## 🎯 Key takeaways
- A health check is a command Docker runs inside the container; `unhealthy` means that command failed, nothing more.
- `HEALTHCHECK` lives in the Dockerfile, so changing it means rebuilding the image and recreating the container.
- `docker inspect -f '{{json .State.Health}}' NAME` shows the diary, and the `Output` tells you why it failed.
- Run the check command by hand with `docker exec` to test the test.
- Orchestrators act on this label (load balancers, Compose, Kubernetes), so a wrong check can take down a healthy app.

## 💎 Lifelong lesson
> Test your tests. A wrong health check is worse than none.

## 🧹 Clean up
```bash
./cleanup.sh
```
(It removes the container, the `d08-tools` image and `work/`.)

## Next →
[D09](../09-status-board-no-dns/README.md): The status board says everything is down. Everything is up.
