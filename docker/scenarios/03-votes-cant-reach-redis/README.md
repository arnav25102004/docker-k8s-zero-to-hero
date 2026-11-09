# D03 · The votes that vanish

*The voting booth is open, but every vote vanishes into thin air.*

⏱ 15 min · beginner · Cats vs Dogs API (built from your own `Dockerfile`) + Redis (`redis:7.4.12-alpine`) · Dockerfile `ENV`, `localhost`, user networks, container names

⬇️ First run downloads about 36 MB (Redis 17 MB + Python base 19 MB) and builds the API image in a few seconds. Do it on good Wi-Fi, before the session.

## 📖 The story
It's the college fest at Christ University, and the Cats vs Dogs poll is on the big screen. On your laptop it worked all week: the app and Redis both ran on `localhost`. Tonight you put each one in its own container, every container says **Up**, and the crowd is tapping the buttons... but the counts never move. The booth is open, and every vote vanishes into thin air.

## 🧠 The concept: why, what, how
Every container gets its **own private network**, like its own flat in an apartment block. Inside a flat, "here" means *this* flat. So `localhost` inside the API container means **the API container itself**, never your laptop and never the Redis container next door.

- `localhost` is a perspective, not a place: it means "me", whoever "me" is.
- To reach another container, use its **name** (`d03-redis`) on a **user-defined network** (`d03-net`). Docker runs a tiny phone book there that turns names into addresses.

```
 Browser ──▶ API container ──✖──▶ "localhost" = the API itself
                  │
                  └────────────▶ d03-redis   (the phone book knows this name)
```

## 🏢 Where you'll meet this at work
- **The #1 docker-compose bug:** an app moved from a laptop (where everything was `localhost`) into containers (every developer, every platform team).
- **A database URL in a config file** that still says `localhost` after the app moves to Kubernetes (developer, SRE).
- **"Works on my machine"** during a Friday deploy, when the only difference is where the dependency lives (SRE).

## 💥 Break it
Here are the files. `break/` holds your own copy of the voting API: `Dockerfile`, `app.py` and `static/`. They are copied there on purpose, so you own a complete project that builds from one folder (the source of truth for the app is `apps/api`; the `Dockerfile` here is a copy with a few lines of its own). Type these yourself, all from this scenario folder (if `work/` already exists, run `rm -rf work` first):
```bash
cp -R break work
docker build -t d03-api:1.0 work
docker network create d03-net
docker run -d --name d03-redis --network d03-net redis:7.4.12-alpine
docker run -d --name d03-api --network d03-net -p 8103:8080 d03-api:1.0
```
Or use the one-line shortcut, which prints (`▶ $`) every command it runs, the same ones as above:
```bash
./break/break.sh
```
(Git Bash on Windows: run `export MSYS_NO_PATHCONV=1` first, so paths are not rewritten.) The room should see: open http://localhost:8103 (playground: the port 8103 URL), press a vote button, and the status bar blinks and the feed shows "Request failed: [Errno 111] Connection refused".

The real run, from `./break.sh` (shortened; the build prints more lines the first time because nothing is cached):
```
✅ Scenario d03 cleaned up
▶ $ rm -rf work
▶ $ cp -R break work
▶ $ docker build -t d03-api:1.0 work
...
▶ $ docker network create d03-net
ea04609a84124f4310d3f741505bacafa244744fa6c2f590e9241a3e41059973
▶ $ docker run -d --name d03-redis --network d03-net redis:7.4.12-alpine
ac5c28f676421f9b75a800c1b6824a32aa629fe60a464ec4f8e791cbada44619
▶ $ docker run -d --name d03-api --network d03-net -p 8103:8080 d03-api:1.0
6331b56e39d4cb041828c762ca49aee9a2584e97514688475530497ca065ecd5
⏳ Waiting for the API to answer on port 8103 . ✔ ready
```

## 🔍 Investigate
Guess first, then run these **in order**. Stay in this scenario folder.

**1. Is the app ready?** Start with the app's own health check.
```bash
curl -s localhost:8103/readyz
```
```
{"status": "not ready", "error": "redis localhost:6379: [Errno 111] Connection refused"}
```
The API says it is *not ready* and names the place it tried: `localhost:6379`.

<details><summary>💡 Hint</summary>
Read the address in that error. Inside the API container, what does <code>localhost</code> point to? Is Redis running <i>there</i>? And who told the API to look there: the run lines you typed, or something else?
</details>

**2. Does Docker agree that everything is fine?** Check what Docker thinks of both containers.
```bash
docker ps --filter name=d03- --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```
```
NAMES       STATUS                    PORTS
d03-api     Up 11 seconds (healthy)   0.0.0.0:8103->8080/tcp, [::]:8103->8080/tcp
d03-redis   Up 11 seconds             6379/tcp
```
Both **Up**, the API even says **(healthy)**. "Healthy" only means the web server answers; it does not mean Redis is reachable. (The columns' exact look depends on your Docker version.)

**3. What does the API's own diary say?**
```bash
docker logs d03-api
```
```
2026-11-09T10:07:02 [6331b56e39d4] 🚀 Cats vs Dogs v1.0.0 (Cats vs Dogs) listening on :8080, votes stored in redis localhost
2026-11-09T10:07:03 [6331b56e39d4] readiness failed: cannot reach redis at localhost:6379: [Errno 111] Connection refused
2026-11-09T10:07:08 [6331b56e39d4] readiness failed: cannot reach redis at localhost:6379: [Errno 111] Connection refused
```
The very first line says it: votes are stored in `redis localhost`. (The lines repeat every few seconds.)

**4. What did Docker actually give the API?** Compare what you wrote with what Docker ran: list the environment of the running container.
```bash
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' d03-api
```
```
PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LANG=C.UTF-8
GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305
PYTHON_VERSION=3.12.16
PYTHON_SHA256=b5796915dc45ff745cfb4e990a7e7c93d6f546328a102ce31448d69ebc37575c
PYTHONDONTWRITEBYTECODE=1
PYTHONUNBUFFERED=1
PORT=8080
REDIS_HOST=localhost
```
(Version numbers may differ on your machine.) There is a `REDIS_HOST=localhost` at the bottom. Look back at the `docker run` line for `d03-api` in the break step: it has no `-e` flag at all. So where did that value come from?

**5. Where was `REDIS_HOST` written down?** The value did not come from the run line, so search the file you built the image from.
```bash
grep ENV work/Dockerfile
```
```
ENV PYTHONDONTWRITEBYTECODE=1 \
ENV REDIS_HOST=localhost
```
There it is: `ENV REDIS_HOST=localhost`, a default baked into the image at build time. (The first line is the start of the earlier `ENV` block; the grep only shows lines that contain the word.)

**6. Is Redis even on the same network?**
```bash
docker network inspect d03-net --format '{{range .Containers}}{{.Name}} {{end}}'
```
```
d03-api d03-redis 
```
Both containers live on `d03-net`, so they *can* talk (the order may differ). Redis is there; the API just isn't looking for it.

**7. Can the API find Redis by name?** Ask Docker's phone book from inside the API container.
```bash
docker exec d03-api python -c "import socket;print(socket.gethostbyname('d03-redis'))"
```
```
172.20.0.2
```
(Your address may differ.) The name works. Now try the name the app is using:
```bash
docker exec d03-api python -c "import socket;print(socket.gethostbyname('localhost'))"
```
```
127.0.0.1
```
`127.0.0.1` is "this very container". Nothing listens on 6379 there.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The `Dockerfile` has `ENV REDIS_HOST=localhost`: a default baked into the image. The `docker run` line for the API never overrides it, so the API looks for Redis at `localhost`, which is the API's own container. Redis runs in a *different* container (`d03-redis`) on the same network, reachable by its name. Nothing was broken in Redis, the network, or the code: one default was never replaced.
</details>

## 🔧 Fix it
What changed: the `Dockerfile` stays exactly as it is. Only the run line for the API gains one flag, `-e REDIS_HOST=d03-redis`:
```
before: docker run -d --name d03-api --network d03-net -p 8103:8080 d03-api:1.0
after:  docker run -d --name d03-api --network d03-net -p 8103:8080 -e REDIS_HOST=d03-redis d03-api:1.0
```
An image carries **defaults** (`ENV` lines in its Dockerfile), and a container can override any of them **at run time** with `-e NAME=value`; the run-time value wins. So why fix it at run time, and not by editing the `ENV` line? A name like `d03-redis` is a fact about *where* the container runs (this network, this laptop), not about the image. If you bake it in, you need a new image for every place you run it. With `-e`, one image runs anywhere, and the same value later moves to a compose file or a Kubernetes manifest. (Just deleting the `ENV` line would be no fix: the app would find no Redis setting and quietly keep votes in its own memory instead.)

By hand: remove the old API container and start a new one with the flag. The image is not rebuilt.
```bash
docker rm -f d03-api
docker run -d --name d03-api --network d03-net -p 8103:8080 -e REDIS_HOST=d03-redis d03-api:1.0
```
Or run `./fix/fix.sh`, which does the same two commands and prints them.

## ✅ Verify it yourself
```bash
curl -s localhost:8103/readyz
```
```
{"status": "ready", "storage": "redis"}
```
Check that the run-time value won over the baked-in one (it is listed first now):
```bash
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' d03-api
```
```
REDIS_HOST=d03-redis
PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LANG=C.UTF-8
...
PORT=8080
```
(shortened.) Now vote in the browser at http://localhost:8103 (playground: the port 8103 URL) and watch the counts go up and stay. Or vote twice from the terminal:
```bash
curl -s "localhost:8103/api/vote?option=cats"
curl -s "localhost:8103/api/vote?option=cats"
```
```
{"voted": "cats", "results": {"cats": 1, "dogs": 0}, "total": 1, "storage": "redis", "served_by": "6db8d9f37fda", "version": "1.0.0"}
{"voted": "cats", "results": {"cats": 2, "dogs": 0}, "total": 2, "storage": "redis", "served_by": "6db8d9f37fda", "version": "1.0.0"}
```
```bash
curl -s localhost:8103/api/results
```
```
{"results": {"cats": 2, "dogs": 0}, "total": 2, "storage": "redis", "served_by": "6db8d9f37fda", "version": "1.0.0"}
```
(`served_by` is the container ID, so yours will differ. If you voted in the browser first, your counts will be higher.)

## 🎯 Key takeaways
- Each container has its own network namespace: `localhost` inside a container means that container.
- An `ENV` line in a Dockerfile is a default baked into the image; `docker run -e NAME=value` overrides it. Read the Dockerfile **and** the run line.
- To reach another container, use its name on a user-defined network (`d03-redis` on `d03-net`).
- A container that is **Up** (even **healthy**) is not necessarily **ready**: `/readyz` and `docker logs` tell the real story. `docker inspect` shows the setting the app actually received.

## 💎 Lifelong lesson
> `localhost` is a perspective, not a place.

## 🧹 Clean up
```bash
./cleanup.sh
```
(This also removes the `work/` folder and the `d03-api:1.0` image.)

## Next →
[D04](../04-vscode-wrong-password/README.md): VS Code says your right password is wrong.
