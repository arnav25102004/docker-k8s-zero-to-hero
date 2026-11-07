# Lab D07: Container Networking: Wiring Up Three Tiers

> ⏱ 45 min · 🟡 Intermediate

## 🎯 What you'll learn
- How containers talk to **each other**, not just to your laptop
- Default bridge vs **user-defined networks**, and why only the latter has DNS
- Build the full Showdown by hand: **browser → frontend (nginx) → app → Redis**
- The `localhost` trap, and how to debug connectivity from inside

## 🧠 Concept in 60 seconds
```
 user-defined network "showdown"          Docker DNS: "api" → 172.20.0.3, "redis" → 172.20.0.2
 ┌──────────────────────────────────────────────────────────────────┐
 │  frontend (nginx) ──http://api:8080──▶ api ──redis:6379──▶ redis  │
 └──────────────────────────────────────────────────────────────────┘
        ▲ -p 8080:8080   (ONLY the frontend is published)
     browsers / phones
```
- Containers on the **same user-defined network** reach each other **by name**.
- On the **default `bridge`** network there is no name resolution; IPs only.
- **Inside a container, `localhost` means that container itself.** Never use it to reach another container.

## 🧪 Hands-on

### Step 1: Look around
```bash
docker network ls
```

### Step 2: The default bridge has no DNS
```bash
docker run -d --name lonely-redis redis:7-alpine
docker run --rm busybox ping -c 1 -W 2 lonely-redis      # bad address 'lonely-redis'
docker rm -f lonely-redis
```

### Step 3: A user-defined network has DNS
```bash
docker network create showdown
docker run -d --name redis --network showdown redis:7-alpine
docker run --rm --network showdown busybox nslookup redis
docker run --rm --network showdown redis:7-alpine redis-cli -h redis ping      # PONG
```

### Step 4: 🎬 Assemble the three tiers
```bash
docker build -t z2h/api:1.0 apps/api
docker build -t z2h/frontend:1.0 apps/frontend

docker run -d --name api      --network showdown -e REDIS_HOST=redis z2h/api:1.0
docker run -d --name frontend --network showdown -p 8080:8080 z2h/frontend:1.0
```
Open **http://localhost:8080**. Look at the "served by" card: it now says **via frontend proxy &lt;id&gt;**. Your request travelled browser → nginx container → app container → Redis container.

```bash
curl -s "localhost:8080/api/vote?option=dogs"; echo
curl -sI localhost:8080/api/info | grep -i -E 'x-frontend|x-served-by'
```
🔍 Only the frontend is published. Try reaching the app or Redis directly from your laptop: you can't, and that's the point.

### Step 5: Add more app containers, live 🔥
Give two more containers the **same network alias** `api`, and Docker DNS will return all of them:
```bash
docker run -d --name api2 --network showdown --network-alias api -e REDIS_HOST=redis z2h/api:1.0
docker run -d --name api3 --network showdown --network-alias api -e REDIS_HOST=redis z2h/api:1.0
docker restart frontend          # nginx looks up "api" at startup
```
Watch the **Pod wall** in the browser: new tiles appear as different containers answer. Votes stay consistent because they all share Redis. Now kill one:
```bash
docker rm -f api2
```
Its tile fades to grey and **the failed counter stays at 0**: nginx retried on a healthy container. That's load balancing **and** failover.

### Step 6: The `localhost` trap 🪤
```bash
docker run -d --name api-bad --network showdown -e REDIS_HOST=localhost z2h/api:1.0
docker exec api-bad wget -qO- localhost:8080/readyz          # 503: cannot reach redis at localhost
docker logs api-bad | tail -2
docker rm -f api-bad
```
This is the class-slide scenario: *"containers are running, but the API cannot connect"*. The same trap, as a stage demo, is [scenario D03](../scenarios/03-votes-cant-reach-redis/README.md).

### Step 7: Debug from inside the network
`nicolaka/netshoot` is a Swiss-army-knife container (dig, curl, nc, tcpdump...):
```bash
docker run --rm -it --network showdown nicolaka/netshoot
#   dig +short api          ← several IPs: one per container with the alias
#   curl -s api:8080/readyz
#   nc -zv redis 6379
#   exit
```

### Step 8: Isolation
```bash
docker network create other
docker run --rm --network other busybox wget -qO- -T 2 http://api:8080/healthz || echo "isolated ✅"
```

## 🏭 In production
- One network per application stack; publish only the entry point, never the database.
- Use **names** (`REDIS_HOST=redis`), never IPs. Kubernetes gives you the same pattern with Services and DNS (Lab K05).
- Debug connectivity layer by layer: **DNS → route → port → app/credentials**.

## ✅ Checkpoint
<details><summary>1. Why does <code>REDIS_HOST=localhost</code> fail inside a container?</summary>

`localhost` is the container's own loopback interface. Redis lives in another container: use its name.
</details>
<details><summary>2. Three containers share the alias <code>api</code>. What does <code>dig api</code> return?</summary>

Three IP addresses. Docker DNS does simple round-robin load balancing across them.
</details>

## 🧹 Cleanup
```bash
docker rm -f redis api api2 api3 frontend 2>/dev/null; docker network rm showdown other 2>/dev/null
```

➡️ Next: [D08: Docker Compose](../08-compose/README.md)
