# D15 · Everything starts. Nothing works.

*"Everything starts. Nothing works. Run it again… and it works?!"*

⏱ 15 min · beginner · "Dosa ratings board", a tiny Python page plus a real PostgreSQL database, wired together with Docker Compose · `depends_on`, start order vs readiness, health checks

⬇️ First run downloads about 116 MB (`postgres:16.15-alpine`) and about 19 MB (`python:3.12-alpine`). Do it on good Wi-Fi, before the session. Output formats of `docker compose ps` (columns, wording) vary a little between Docker versions; the ideas are the same.

## 📖 The story
Sunday night, the college hostel. Meera finishes a "Dosa ratings board" for the food-club: a web page and a database, two containers, one `compose.yaml`. She types `docker compose up -d`. Compose lists both containers as *Started*, no errors. She opens the page: nothing. She runs the same command again and it works. Monday morning, her friend's laptop does the same thing in the other direction. *"It's flaky,"* says everyone. It isn't flaky. It is **timing**.

## 🧠 The concept: why, what, how
A database is not instantly ready when its container starts. PostgreSQL first sets itself up (creates files, runs an internal start-up, restarts for real), and only then **opens its door** for connections. That takes a couple of seconds.

`depends_on: [db]` in Compose says only: *"start `db` first, then `app`."* That is **start order**. It does **not** say *"wait until `db` is ready."* Think of a **breakfast cafe**: the cook has arrived and switched the stove on, but the first dosa is not ready for another ten minutes. "The cook is here" and "breakfast is served" are different facts.

Our app is impatient on purpose: at start-up it knocks on `db:5432` exactly once, and if nobody answers it gives up and exits. (Many real apps retry; some don't.)

Compose has a way to wait for *ready*: give `db` a **health check** (a small command Docker runs again and again, here `pg_isready`) and tell `app` `condition: service_healthy`.

```
depends_on: [db]        db starts ─▶ app starts at once ─▶ door still closed ─▶ app exits 1
service_healthy         db starts ─▶ health check… healthy ─▶ app starts ─▶ door open ─▶ 200
```

## 🏢 Where you'll meet this at work
- **Flaky CI**: the test job starts the database and the tests in the same second; the pipeline is red one run, green the next (developer, platform team).
- **The morning server reboot**: after a power cut, everything boots at once and the app dies because the database wasn't up yet (SRE, ops).
- **Kubernetes**: the same idea returns as init containers and readiness probes (that is K-26 in this course).

## 💥 Break it
```bash
cd break && ./break.sh
```
The script runs `docker compose up -d` and waits a moment. The room should see Compose's own output, ending with both containers started and no error (shortened; the exact look depends on your Compose version):
```
 Container d15-db-1 Started
 Container d15-app-1 Started
```
Everything looks fine. Now open http://localhost:8115 (playground: the port 8115 URL): **the browser says it can't be reached.**

## 🔍 Investigate
Guess first, then run these **in order**. They work from any folder, because we named the project `d15`.

**1. What state is everything in?** (`-a` also lists containers that have stopped)
```bash
docker compose -p d15 ps -a
```
```
NAME        IMAGE                   COMMAND                  SERVICE   CREATED         STATUS                     PORTS
d15-app-1   python:3.12-alpine      "python /app/app.py"     app       5 seconds ago   Exited (1) 4 seconds ago   
d15-db-1    postgres:16.15-alpine   "docker-entrypoint.s…"   db        5 seconds ago   Up 5 seconds               5432/tcp
```
The database is up. The app **exited with code 1** a second after it started.

<details><summary>💡 Hint</summary>
The app died almost instantly, while the database is perfectly fine <em>now</em>. What did the app need at the very moment it started? Was the database really "open for business" yet?
</details>

**2. Why did the app exit?**
```bash
docker compose -p d15 logs app
```
```
app-1  | ❌ database not reachable (db:5432): [Errno 111] Connection refused
```
"Connection refused" = nobody was listening on that port at that moment.

**3. What was the database doing?** Add timestamps (`-t`) and keep only the two telling lines:
```bash
docker compose -p d15 logs -t | grep -E "not reachable|ready to accept"
```
```
app-1  | 2026-11-07T18:55:10.335553722Z ❌ database not reachable (db:5432): [Errno 111] Connection refused
db-1   | 2026-11-07T18:55:10.561672222Z 2026-11-07 18:55:10 UTC [41] LOG:  database system is ready to accept connections
db-1   | 2026-11-07T18:55:10.776539500Z 2026-11-07 18:55:10 UTC [1] LOG:  database system is ready to accept connections
```
(Shortened; your times will differ.) Read the clock: the app gave up at `.335`, and the database only said **"ready to accept connections"** at `.561` (a temporary start-up server used while setting up) and again at `.776` (the real one). The app knocked **before** the door existed. Run `docker compose -p d15 logs db` to see the whole start-up if you're curious.

**4. Prove it's only timing.** Start just the app again, now that the database has had time:
```bash
docker compose -p d15 start app
sleep 2
curl -s -o /dev/null -w '%{http_code}\n' localhost:8115
```
```
 Container d15-app-1 Starting 
 Container d15-app-1 Started 
200
```
Same code, same files, now it works. That is the "run it again and it works?!" moment: nothing was broken except the **order of events**.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

`depends_on: [db]` only makes Compose start `db` before `app`. It does not wait for PostgreSQL to finish setting itself up. The app made its single connection attempt while Postgres was still initialising and its TCP port was closed, got "connection refused", and exited (`restart: "no"` means nobody brought it back). A second `up` worked only because by then the database was ready.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: `break/` and `fix/` hold the same `app.py`. Only `compose.yaml` differs:
```bash
diff ../break/compose.yaml compose.yaml
```
```
1c1
< # D15 break: depends_on only controls START ORDER. It does not wait for "ready".
---
> # D15 fix: the db reports when it is READY, and app waits for that.
12a13,16
>     healthcheck:
>       test: ["CMD-SHELL", "pg_isready -h 127.0.0.1 -U postgres"]
>       interval: 2s
>       retries: 15
25c29,30
<       - db
---
>       db:
>         condition: service_healthy
```
The database now reports *ready* (`pg_isready` is Postgres's own "are you open?" tool; `-h 127.0.0.1` makes it knock on the network door the app will use), and the app waits for `service_healthy`. By hand, this replaces `./fix.sh`:
```bash
docker compose -p d15 -f compose.yaml up -d
```

## ✅ Verify it yourself
Run these in order, right after the fix:
```bash
docker compose -p d15 ps
```
```
NAME        IMAGE                   COMMAND                  SERVICE   CREATED         STATUS                   PORTS
d15-app-1   python:3.12-alpine      "python /app/app.py"     app       4 seconds ago   Up 1 second              0.0.0.0:8115->8000/tcp, [::]:8115->8000/tcp
d15-db-1    postgres:16.15-alpine   "docker-entrypoint.s…"   db        4 seconds ago   Up 3 seconds (healthy)   5432/tcp
```
`(healthy)` on the database, and the app is **Up**. Open http://localhost:8115 (playground: the port 8115 URL): a green **✅ connected to the database** and four dosa ratings. Or from the terminal:
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:8115
```
```
200
```
One honest note: the page only checks that it can **reach** the database. The four ratings are fixed demo data, not rows from Postgres. Last, the clock again:
```bash
docker compose -p d15 logs -t | grep -E "not reachable|ready to accept|connected to"
```
```
app-1  | 2026-11-07T18:55:26.318127757Z ✅ connected to the database
db-1   | 2026-11-07T18:55:23.473254631Z 2026-11-07 18:55:23 UTC [1] LOG:  database system is ready to accept connections
```
(Shortened; your times will differ.) Now the order is right: the database said **ready** first, and only then did the app connect. 🎉

## 🎯 Key takeaways
- `depends_on` controls **start order**, not **readiness**. "Started" is not "ready".
- A `healthcheck` tells Docker how to test that a service is really ready. `docker compose ps` shows `(healthy)`.
- `depends_on: db: condition: service_healthy` makes the dependant wait for that.
- Clues to spot this bug: exit code 1 within a second, "connection refused", and a database log whose "ready" line is **later** than the app's death. Always compare timestamps.

## 💎 Lifelong lesson
> Started is not ready. Wait for ready.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
That was the last Docker scenario, well done. Next → Kubernetes track (coming next). Or go back to the [scenario list](../README.md).
