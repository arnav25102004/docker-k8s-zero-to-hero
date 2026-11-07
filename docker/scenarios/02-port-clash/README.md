# D02 · Two great apps, one door

*Two great apps. One door. Only one gets in.*

⏱ 10 min · beginner · Excalidraw (`excalidraw/excalidraw`) + IT-Tools (`corentinth/it-tools`) · port publishing, `-p HOST:CONTAINER`
⬇️ First run downloads about 68 MB (Excalidraw 44 MB + IT-Tools 24 MB). Do it on good Wi-Fi, before the session.

## 📖 The story
It's hackathon night at a Bengaluru startup. Your team already has Excalidraw open on port 8102 for the whiteboard session. Someone says, *"Start IT-Tools too, we need a JSON formatter,"* and pastes the same `-p 8102:80` they used before. Docker prints an error, nobody reads it, and IT-Tools never shows up. Two great apps, one door.

## 🧠 The concept: why, what, how
`-p 8102:80` means **HOST port : CONTAINER port**. Think of a hotel: every room (container) has its own door number 80 *inside*, and nobody minds that two rooms both have a "Room 80". But the hotel (your laptop) has just one front desk with numbered counters, and **counter 8102 can serve only one room at a time**.

- The **container side** (`:80`) can repeat freely, because each container has its own private network.
- The **host side** (`8102:`) is shared by the whole machine, so it must be unique.
- To run two apps, keep `:80` and change the number in front: `-p 8202:80`.

## 🏢 Where you'll meet this at work
- **A VM with two services that both want 8080** (developer, SRE).
- **A forgotten dev server** still running from last week, quietly holding the port (every developer).
- **Local Postgres vs Docker Postgres** both wanting 5432 on a laptop (developer).

## 💥 Break it
```bash
cd break && ./break.sh
```
Excalidraw starts fine. Then IT-Tools fails, and the script lets the real Docker error print:
```
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint d02-tools (...): Bind for 0.0.0.0:8102 failed: port is already allocated
```
Laptop: http://localhost:8102 shows Excalidraw. Playground: open the port 8102 URL. IT-Tools has no address at all.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Read the error slowly.** Say the last words out loud: *"Bind for 0.0.0.0:8102 failed: port is already allocated."* Which port? Who might have it?

**2. What happened to IT-Tools?**
```bash
docker ps -a
```
```
CONTAINER ID   IMAGE                                    COMMAND                  CREATED                  STATUS                           PORTS                                     NAMES
35ad6b523497   corentinth/it-tools:2024.10.22-7ca5933   "/docker-entrypoint.…"   Less than a second ago   Created                                                                    d02-tools
746e10620cab   excalidraw/excalidraw:latest             "/docker-entrypoint.…"   1 second ago             Up 1 second (health: starting)   0.0.0.0:8102->80/tcp, [::]:8102->80/tcp   d02-draw
```
`d02-tools` is stuck in **Created**: Docker built the box but could not switch it on. Look at the PORTS column of the other row. (Your list may also show other containers.)

**3. Who is using 8102?**
```bash
docker ps --filter publish=8102
```
```
CONTAINER ID   IMAGE                          COMMAND                  CREATED         STATUS                           PORTS                                     NAMES
746e10620cab   excalidraw/excalidraw:latest   "/docker-entrypoint.…"   2 seconds ago   Up 1 second (health: starting)   0.0.0.0:8102->80/tcp, [::]:8102->80/tcp   d02-draw
```
Exactly one container holds the port, and its name is in the last column.

**4. Confirm from the owner's side.**
```bash
docker port d02-draw
```
```
80/tcp -> 0.0.0.0:8102
80/tcp -> [::]:8102
```
Container port 80 is mapped to host port 8102. Now ask the same question about IT-Tools:
```bash
docker port d02-tools
```
(Prints nothing: it never got a port.)

<details><summary>💡 Hint</summary>
Both containers listen on port 80 <i>inside</i>, and that is fine. Which side of <code>8102:80</code> is shared by the whole laptop?
</details>

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

Host port 8102 is already published by `d02-draw`. A host port can be bound by only one container (or program) at a time, so Docker refused to start `d02-tools` and left it in `Created`. The container port 80 was never the problem.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: only the number *before* the colon. The two `IT-Tools` run lines side by side:
```bash
grep -o -h -e '-p 8[0-9]*:80 "$TOOLS_IMAGE"' ../break/break.sh fix.sh
```
```
-p 8102:80 "$TOOLS_IMAGE"
-p 8202:80 "$TOOLS_IMAGE"
```
(`break.sh` first, `fix.sh` second: `8102` became `8202`, the `:80` stayed.)

By hand: `docker rm -f d02-tools`, then run it again on a free host port:
```bash
docker rm -f d02-tools
docker run -d --name d02-tools -p 8202:80 corentinth/it-tools:2024.10.22-7ca5933
```

## ✅ Verify it yourself
```bash
docker ps --format '{{.Names}}  {{.Ports}}'
```
```
d02-tools  0.0.0.0:8202->80/tcp, [::]:8202->80/tcp
d02-draw  0.0.0.0:8102->80/tcp, [::]:8102->80/tcp
```
Open http://localhost:8102 (Excalidraw) and http://localhost:8202 (IT-Tools). Playground: the port 8102 and port 8202 URLs. Both open.
```bash
curl -sI localhost:8102 | head -1
curl -sI localhost:8202 | head -1
```
```
HTTP/1.1 200 OK
HTTP/1.1 200 OK
```

## 🎯 Key takeaways
- `-p HOST:CONTAINER`: the host side must be unique, the container side can repeat.
- A container stuck in `Created` was built but never started; the error told you why.
- `docker ps --filter publish=PORT` finds who holds a port; `docker port NAME` shows a container's mappings.
- When a port is taken, change the host number, not the app.

## 💎 Lifelong lesson
> Read the first error line slowly. It usually names the culprit.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
D03: Cats vs Dogs voting app that can't reach Redis.
