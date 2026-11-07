# Lab D03: Meet the Showdown: ports, logs, exec, inspect

> ⏱ 45 min · 🟢 Beginner

## 🎯 What you'll learn
- Run the course app, **🐱 Cats vs 🐶 Dogs**, and vote from your browser (and your phone!)
- Publish ports with `-p` and understand why "running" isn't "reachable"
- The five debugging commands you'll use forever: `logs`, `exec`, `inspect`, `stats`, `cp`
- Why votes **vanish** when a container is replaced. Hold on to that cliffhanger.

## 🧠 Concept in 60 seconds
```
  your laptop                     container
 ┌────────────────┐  -p 8080:8080 ┌───────────────────┐
 │ localhost:8080 ├──────────────▶│ showdown app :8080│
 └────────────────┘               └───────────────────┘
   host port ─────────────────────── container port
```
A container has its **own private network**. Its port 8080 is invisible from outside until you **publish** it.

## 🧪 Hands-on

### Step 1: Build the app (one time)
From the repository root:
```bash
docker build -t z2h/api:1.0 apps/api
```
*(Lab D04 explains every line of that Dockerfile.)*

### Step 2: 🎬 Showtime
```bash
docker run -d --name showdown -p 8080:8080 z2h/api:1.0
```
Open **http://localhost:8080** and vote. 🐱🐶

Look at the **"served by"** card: that random-looking name is the **container ID**. Check it:
```bash
docker ps
```

### Step 3: 📱 Let the whole room vote
`-p 8080:8080` publishes on **all** network interfaces of your laptop. Anyone on the same Wi-Fi can join:
```bash
# macOS
ipconfig getifaddr en0
# Linux
hostname -I | awk '{print $1}'
```
Share `http://<that-ip>:8080`, and the audience votes from their phones. *(If nobody can connect, the laptop firewall or a guest Wi-Fi with client isolation is blocking it.)*

### Step 4: The same thing from the terminal
```bash
curl -s localhost:8080/api/info
curl -s "localhost:8080/api/vote?option=cats"
curl -s "localhost:8080/api/vote?option=dogs"
curl -s localhost:8080/api/results
```
> 💡 Always **quote URLs that contain `?`**. zsh (the default macOS shell) otherwise fails with `no matches found`.

### Step 5: Running ≠ reachable
```bash
docker run -d --name hidden z2h/api:1.0          # no -p
docker ps --filter name=hidden                    # Up!
curl -s --max-time 2 localhost:8080/api/info >/dev/null && echo "that's the OTHER container"
docker port hidden                                # nothing published
```
The `hidden` container runs perfectly, and **no one can reach it**. Keep this in mind; it comes back in production as "the service is up but users get errors".

### Step 6: Logs
```bash
docker logs showdown
docker logs -f showdown          # follow; vote in the browser and watch lines appear. Ctrl+C to stop
docker logs --tail 3 --timestamps showdown
```
🔍 The app writes to **stdout**, and Docker captures it. That's the container logging contract.

### Step 7: Exec: step inside a running container
```bash
docker exec showdown ls -la /app
docker exec showdown id                  # uid=10001: not root (Lab D05 explains why)
docker exec -it showdown sh
#   ps                                   # python is PID 1
#   hostname                             # the container ID again
#   wget -qO- localhost:8080/healthz
#   exit
```

### Step 8: Inspect: the source of truth
```bash
docker inspect showdown --format '{{.State.Status}} since {{.State.StartedAt}}'
docker inspect showdown --format '{{json .Config.Env}}'
docker inspect showdown --format '{{json .NetworkSettings.Ports}}'
docker inspect showdown --format '{{.State.Health.Status}}'       # the image has a HEALTHCHECK
```

### Step 9: Live resource usage
```bash
docker stats --no-stream
docker top showdown
```

### Step 10: Copy files out (and in)
```bash
docker cp showdown:/app/app.py ./peek.py && head -25 peek.py && rm peek.py
```

### Step 11: 💥 The cliffhanger
Note your vote counts. Now **replace** the container, which is exactly what every deployment does:
```bash
docker rm -f showdown
docker run -d --name showdown -p 8080:8080 z2h/api:1.0
```
Refresh the browser. **Every vote is gone.** 😱

The UI already warned you: *"⚠️ votes in this container's memory"*. A container's memory and writable layer die with it. How do real apps survive deploys, crashes, and restarts? → **Labs D06–D08.**

## 🏭 In production
- **Investigate with `exec`, never repair with it.** Changes made inside a container vanish when it's replaced, and nobody knows they happened.
- Log platforms (Loki, ELK, CloudWatch, Datadog) collect container **stdout/stderr**. Apps that log to files inside the container are invisible to them.
- `docker inspect` settles arguments: it shows what is *actually* configured.

## 🏆 Challenge
1. Run a second copy on port 8081 with a different title: `-e TITLE="Tea vs Coffee" -e VOTE_OPTIONS="tea:🍵:Tea,coffee:☕:Coffee"`. Two apps, one image.
2. Start a third copy on port 8080 again. Read the error. (This is [scenario D02](../scenarios/02-port-clash/README.md).)
3. Using only `docker inspect`, find which command the container runs.

## ✅ Checkpoint
<details><summary>1. In <code>-p 9000:8080</code>, which port do you open in the browser?</summary>

`9000`, the host side. The format is `HOST:CONTAINER`.
</details>
<details><summary>2. Why did the votes disappear in Step 11?</summary>

They were stored in the container's process memory. Removing the container destroyed it, and the new container started empty.
</details>

## 🧹 Cleanup
```bash
docker rm -f showdown hidden 2>/dev/null
```

➡️ Next: [D04: Your First Dockerfile](../04-first-dockerfile/README.md)
