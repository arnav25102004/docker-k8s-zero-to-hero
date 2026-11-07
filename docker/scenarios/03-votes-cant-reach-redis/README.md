# D03 · The votes that vanish

*The voting booth is open, but every vote vanishes into thin air.*

⏱ 10 min · beginner · Cats vs Dogs API (built from `apps/api`) + Redis (`redis:7.4.12-alpine`) · container networking, `localhost`, service names

⬇️ First run downloads about 36 MB (Redis 17 MB + Python base 19 MB) and builds the API image in a few seconds. Do it on good Wi-Fi, before the session.

## 📖 The story
It's the college fest at Christ University, and the Cats vs Dogs poll is on the big screen. On your laptop it worked all week: the app and Redis both ran on `localhost`. Tonight you put each one in its own container, every container says **Up**, and the crowd is tapping the buttons... but the counts never move. The booth is open, and every vote vanishes into thin air.

## 🧠 The concept: why, what, how
Every container gets its **own private network**, like its own flat in an apartment block. Inside a flat, "here" means *this* flat. So `localhost` inside the API container means **the API container itself**, never your laptop and never the Redis container next door.

- `localhost` is a perspective, not a place: it means "me", whoever "me" is.
- To reach another container, use its **name** (`d03-redis`) on a **user-defined network** (`d03-net`). Docker runs a tiny phone book there that turns names into addresses.
- Containers on the same network can call each other by name. No `-p` needed between them.

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
```bash
cd break && ./break.sh
```
The script builds the API, starts Redis and the API, and says both are Up. What the room should see: the app opens at http://localhost:8103 (playground: the port 8103 URL), but pressing a vote button fails: the status bar blinks and the feed shows "Request failed: [Errno 111] Connection refused".

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is the app ready?** Start with the app's own health check.
```bash
curl -s localhost:8103/readyz
```
```
{"status": "not ready", "error": "redis localhost:6379: [Errno 111] Connection refused"}
```
The API says it is *not ready* and names the place it tried: `localhost:6379`.

<details><summary>💡 Hint</summary>
Read the address in that error. Inside the API container, what does <code>localhost</code> point to? Is Redis running <i>there</i>?
</details>

**2. What does the API's own diary say?**
```bash
docker logs d03-api
```
```
2026-11-07T14:20:04 [64d94ae76c95] 🚀 Cats vs Dogs v1.0.0 (Cats vs Dogs) listening on :8080, votes stored in redis localhost
2026-11-07T14:20:05 [64d94ae76c95] readiness failed: cannot reach redis at localhost:6379: [Errno 111] Connection refused
```
(shortened) The very first line says it: votes are stored in `redis localhost`.

**3. What was the API told?**
```bash
docker exec d03-api printenv REDIS_HOST
```
```
localhost
```
That is the setting the app reads to find Redis.

**4. Is Redis even on the same network?**
```bash
docker network inspect d03-net --format '{{range .Containers}}{{.Name}} {{end}}'
```
```
d03-redis d03-api 
```
Both containers live on `d03-net`, so they *can* talk. Redis is there; the API just isn't looking for it.

**5. Can the API find Redis by name?** Ask Docker's phone book from inside the API container.
```bash
docker exec d03-api python -c "import socket;print(socket.gethostbyname('d03-redis'))"
```
```
172.19.0.2
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

The API looks for Redis at `localhost`, which is the API's own container. Redis runs in a *different* container (`d03-redis`) on the same network, reachable by its name. Nothing was broken in Redis, the network, or the code: only one setting was wrong.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: only the value of `REDIS_HOST`.
```bash
grep -h -o -e '-e REDIS_HOST=[a-z0-9-]*' ../break/break.sh fix.sh
```
```
-e REDIS_HOST=localhost
-e REDIS_HOST=d03-redis
```
(`break.sh` first, `fix.sh` second: `localhost` became `d03-redis`.)

By hand: remove the API and start it again, pointing at Redis by name.
```bash
docker rm -f d03-api
docker run -d --name d03-api --network d03-net -p 8103:8080 -e REDIS_HOST=d03-redis d03-api:1.0
```

## ✅ Verify it yourself
```bash
curl -s localhost:8103/readyz
```
```
{"status": "ready", "storage": "redis"}
```
Now vote in the browser at http://localhost:8103 (playground: the port 8103 URL) and watch the counts go up and stay. Or vote twice from the terminal:
```bash
curl -s "localhost:8103/api/vote?option=cats"
curl -s "localhost:8103/api/vote?option=cats"
```
```
{"voted": "cats", "results": {"cats": 1, "dogs": 0}, "total": 1, "storage": "redis", "served_by": "074d06521ec9", "version": "1.0.0"}
{"voted": "cats", "results": {"cats": 2, "dogs": 0}, "total": 2, "storage": "redis", "served_by": "074d06521ec9", "version": "1.0.0"}
```
```bash
curl -s localhost:8103/api/results
```
```
{"results": {"cats": 2, "dogs": 0}, "total": 2, "storage": "redis", "served_by": "074d06521ec9", "version": "1.0.0"}
```
(`served_by` is the container ID, so yours will differ. If you voted in the browser first, your counts will be higher.)

## 🎯 Key takeaways
- Each container has its own network namespace: `localhost` inside a container means that container.
- To reach another container, use its name on a user-defined network (`d03-redis` on `d03-net`).
- A container that is **Up** is not necessarily **ready**: `/readyz` and `docker logs` tell the real story.
- Check the setting the app actually received: `docker exec NAME printenv VAR`.

## 💎 Lifelong lesson
> `localhost` is a perspective, not a place.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
[D04](../04-vscode-wrong-password/README.md): VS Code says your right password is wrong.
