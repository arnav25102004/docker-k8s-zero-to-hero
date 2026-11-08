# D08 · Healthy app, sick label

*The app works perfectly. Docker swears it's sick.*

⏱ 10 min · beginner · IT-Tools (`corentinth/it-tools`) · health checks, `docker inspect`

⬇️ First run downloads about 24 MB (IT-Tools). Do it on good Wi-Fi, before the session. If you already did D02 or D05, it's cached.

## 📖 The story
It's the night before the campus fest registration opens. Your team's tools page runs in a container, and the monitoring dashboard has just turned red: **unhealthy**. Someone opens the page in a browser. It loads instantly and works. *"The monitor is broken!"* says one friend. *"The app is broken!"* says another. Who is right?

## 🧠 The concept: why, what, how
Docker cannot see inside your app, so it asks. A **health check** is a small command that Docker runs *inside the container* every few seconds. Exit code `0` means "all good"; anything else is a strike. After enough strikes in a row, Docker labels the container `unhealthy`.

Think of the **floor manager** knocking on a hotel room door every few minutes: "Everything okay in there?" If the manager knocks on the wrong door (room 8080 instead of room 80), nobody answers, and the manager writes "guest missing" in the register, even though the guest is happily watching TV in room 80.

- `unhealthy` is a verdict about **the check**, not proof about **the app**.
- The check is code too, and code has bugs.

## 🏢 Where you'll meet this at work
- **Load balancers** that stop sending traffic to servers that fail their health check (SRE, platform team).
- **Docker Compose `depends_on: condition: service_healthy`**, where one service waits for another to be healthy before it starts (developer).
- **Kubernetes liveness and readiness probes**, the same idea at cluster scale. A wrong readiness probe keeps a healthy app from ever getting visitors ([K06](../../../kubernetes/scenarios/06-kanboard-never-ready/README.md)), and an impatient liveness probe restarts a perfectly good app forever ([K07](../../../kubernetes/scenarios/07-showdown-slow-start/README.md)).

## 💥 Break it
```bash
cd break && ./break.sh
```
The script waits until Docker has given its verdict, then stops. The room should see that the app opens fine in the browser, and the container is marked `unhealthy`.

Laptop: http://localhost:8108 shows IT-Tools. Playground: open the port 8108 URL.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. What does Docker say?**
```bash
docker ps --filter name=d08-tools
```
```
CONTAINER ID   IMAGE                                    COMMAND                  CREATED          STATUS                      PORTS                                     NAMES
18799ab29e15   corentinth/it-tools:2024.10.22-7ca5933   "/docker-entrypoint.…"   14 seconds ago   Up 13 seconds (unhealthy)   0.0.0.0:8108->80/tcp, [::]:8108->80/tcp   d08-tools
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
{"Status":"unhealthy","FailingStreak":2,"Log":[{"Start":"2026-11-07T18:08:18.847663129Z","End":"2026-11-07T18:08:18.874078254Z","ExitCode":1,"Output":"wget: can't connect to remote host (127.0.0.1): Connection refused\n"},{"Start":"2026-11-07T18:08:21.875778172Z","End":"2026-11-07T18:08:21.905836547Z","ExitCode":1,"Output":"wget: can't connect to remote host (127.0.0.1): Connection refused\n"}]}
```
(Your times will differ.) Read the `Output`: *"Connection refused."* Nobody answered the knock. Two strikes in a row (`FailingStreak: 2`), and Docker gave the verdict. Run the command again and again: the number keeps climbing every 3 seconds. Docker flipped the label after 2 in a row.

**4. What exactly is the check?**
```bash
docker inspect -f '{{json .Config.Healthcheck}}' d08-tools
```
```
{"Test":["CMD-SHELL","wget -qO- http://127.0.0.1:8080/ || exit 1"],"Interval":3000000000,"Retries":2}
```
The check calls port **8080**. It runs every 3 seconds (`Interval` is in nanoseconds), and 2 failures in a row means unhealthy.

**5. Test the test.** Run the very same command by hand, inside the container, on the port in the check and then on port 80 (the port Docker is publishing as 8108):
```bash
docker exec d08-tools sh -c 'wget -qO- http://127.0.0.1:8080/ >/dev/null; echo "exit=$?"'
docker exec d08-tools sh -c 'wget -qO- http://127.0.0.1:80/ >/dev/null; echo "exit=$?"'
```
```
wget: can't connect to remote host (127.0.0.1): Connection refused
exit=1
exit=0
```
Port 8080 fails (exit 1), port 80 works (exit 0).

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The health check probes port **8080**, but IT-Tools listens on port **80**. The check fails every time, so Docker reports `unhealthy`. The app was never sick; the check was knocking on the wrong door.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: only the port in the health check. The health-check address in each script:
```bash
grep -H -o -e "http://127.0.0.1:[0-9]*/" ../break/break.sh fix.sh
```
```
../break/break.sh:http://127.0.0.1:8080/
fix.sh:http://127.0.0.1:80/
```
(`break.sh` first, `fix.sh` second: `8080` became `80`.)

A running container's health check can't be edited, so by hand you recreate it:
```bash
docker rm -f d08-tools
docker run -d --name d08-tools -p 8108:80 \
  --health-cmd 'wget -qO- http://127.0.0.1:80/ || exit 1' --health-interval 3s --health-retries 2 \
  corentinth/it-tools:2024.10.22-7ca5933
```

## ✅ Verify it yourself
```bash
docker ps --filter name=d08-tools
```
```
CONTAINER ID   IMAGE                                    COMMAND                  CREATED         STATUS                   PORTS                                     NAMES
be874c6ce645   corentinth/it-tools:2024.10.22-7ca5933   "/docker-entrypoint.…"   3 seconds ago   Up 3 seconds (healthy)   0.0.0.0:8108->80/tcp, [::]:8108->80/tcp   d08-tools
```
`(healthy)` now. (Right after the fix it may briefly say `(health: starting)`; run it again.)
```bash
docker inspect -f '{{.State.Health.Status}}' d08-tools
docker inspect -f '{{json .Config.Healthcheck}}' d08-tools
curl -sI localhost:8108 | head -1
```
```
healthy
{"Test":["CMD-SHELL","wget -qO- http://127.0.0.1:80/ || exit 1"],"Interval":3000000000,"Retries":2}
HTTP/1.1 200 OK
```
Open http://localhost:8108 again. Playground: the port 8108 URL. Same app as before; only the label changed.

## 🎯 Key takeaways
- A health check is a command Docker runs inside the container; `unhealthy` means that command failed, nothing more.
- `docker inspect -f '{{json .State.Health}}' NAME` shows the diary, and the `Output` tells you why it failed.
- Run the check command by hand with `docker exec` to test the test.
- Orchestrators act on this label (load balancers, Compose, Kubernetes), so a wrong check can take down a healthy app.

## 💎 Lifelong lesson
> Test your tests. A wrong health check is worse than none.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
[D09](../09-status-board-no-dns/README.md): The status board says everything is down. Everything is up.
