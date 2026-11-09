# D02 · Two great apps, one door

*Two great apps. One door. Only one gets in.*

⏱ 10 min · beginner · Excalidraw (`excalidraw/excalidraw`) + IT-Tools (`corentinth/it-tools`) · port publishing, `-p HOST:CONTAINER`
⬇️ First run downloads about 68 MB (Excalidraw 44 MB + IT-Tools 24 MB). Do it on good Wi-Fi, before the session.

There is **no Dockerfile in this scenario**, because both apps are ready-made third-party images that we run exactly as published, so the only thing you write is the two `docker run` lines.

## 📖 The story
It's hackathon night at a Bengaluru startup. Your team already has Excalidraw open on port 8102 for the whiteboard session. Someone says, *"Start IT-Tools too, we need a JSON formatter,"* and pastes the same `-p` flag they used before. Docker prints an error, nobody reads it, and IT-Tools never shows up. Two great apps, one door.

## 🧠 The concept: why, what, how
A container lives on its own private network, so by default nothing on your laptop (and nothing in your browser) can reach it. **Publishing a port** with `-p HOST:CONTAINER` cuts a door through that wall:

- the number **after** the colon is the port the app listens on *inside* the container (Excalidraw and IT-Tools both serve web pages on `80`);
- the number **before** the colon is the port that opens on *your laptop*, the one you type after `localhost:`.

Think of a hotel: the guests are in rooms (containers), and visitors come to the front desk (your laptop) and ask for a counter number. `-p 8102:80` says: *"visitors who ask for counter 8102 get sent to Room 80."*

```
browser ──▶ localhost:8102 ──(-p 8102:80)──▶ container, port 80
```

## 🏢 Where you'll meet this at work
- **A VM with two services that both want 8080** (developer, SRE).
- **A forgotten dev server** still running from last week, quietly holding a port (every developer).
- **Local Postgres vs Docker Postgres** both wanting 5432 on a laptop (developer).

## 💥 Break it
Type these two lines yourself, one after the other. The first starts Excalidraw. The second starts IT-Tools. (The Excalidraw image name is long on purpose: it is pinned to one exact version, so copy and paste it from here.)

```bash
./cleanup.sh
```
(Safe at any time; it makes a repeat run start clean.)
```bash
docker run -d --name d02-draw -p 8102:80 excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9
```
```bash
docker run -d --name d02-tools -p 8102:80 corentinth/it-tools:2024.10.22-7ca5933
```
(`-d` runs it in the background, `--name` gives it a name we can find later. On Git Bash for Windows, nothing here needs changing.)

The first line prints a long container id. The second prints an id *and then an error*:
```
b7d61de55e57e91cad13411ef754e8bce501e6c4464a20463ac373fc275f8f78
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint d02-tools (87d7...): Bind for 0.0.0.0:8102 failed: port is already allocated
```
(shortened; the exact wording can differ a little between Docker versions.) Laptop: http://localhost:8102 shows Excalidraw. Playground: open the port 8102 URL. IT-Tools has no address at all.

**Shortcut:** `./break/break.sh` types the same two lines for you. It prints each one as `▶ $ docker run …` before running it, so you can compare with the lines above.

## 🔍 Investigate
Guess first, then run these **in order**. Every step compares what you *typed* (the two lines above) with what Docker *did*.

**1. Read the error slowly.** *Why first: the error is the only thing Docker said, and it is easy to skim past.* Say the last words out loud: *"Bind for 0.0.0.0:8102 failed: port is already allocated."* Which port? Who might have it?

<details><summary>💡 Hint</summary>
Both containers listen on port 80 <i>inside</i>, and that is fine. Compare your two <code>docker run</code> lines: which number is the same in both, and is that the side that belongs to one container or to the whole laptop?
</details>

**2. What happened to IT-Tools?** *Why next: the error says "failed", but did the container exist at all?*
```bash
docker ps -a --filter name=d02-
```
```
CONTAINER ID   IMAGE                                    COMMAND                  CREATED          STATUS                             PORTS                                     NAMES
b7d61de55e57   corentinth/it-tools:2024.10.22-7ca5933   "/docker-entrypoint.…"   4 seconds ago    Created                                                                      d02-tools
e9fb8b85fa13   excalidraw/excalidraw:latest             "/docker-entrypoint.…"   14 seconds ago   Up 13 seconds (health: starting)   0.0.0.0:8102->80/tcp, [::]:8102->80/tcp   d02-draw
```
`d02-tools` is stuck in **Created**: Docker built the box but could not switch it on. Look at the PORTS column of the other row. (Without the `--filter`, your list may also show other containers.)

**3. What did each container ask for?** *Why next: this is Docker's own record of the flags you typed.*
```bash
docker inspect -f '{{json .HostConfig.PortBindings}}' d02-draw
docker inspect -f '{{json .HostConfig.PortBindings}}' d02-tools
```
```
{"80/tcp":[{"HostIp":"","HostPort":"8102"}]}
{"80/tcp":[{"HostIp":"","HostPort":"8102"}]}
```
Two identical requests: container port `80/tcp` wanted on `HostPort` `8102`, twice.

**4. Who is using 8102?** *Why next: we now suspect the port, so ask Docker who holds it.*
```bash
docker ps --filter publish=8102
```
```
CONTAINER ID   IMAGE                          COMMAND                  CREATED          STATUS                             PORTS                                     NAMES
e9fb8b85fa13   excalidraw/excalidraw:latest   "/docker-entrypoint.…"   26 seconds ago   Up 25 seconds (health: starting)   0.0.0.0:8102->80/tcp, [::]:8102->80/tcp   d02-draw
```
Exactly one container holds the port, and its name is in the last column.

**5. Confirm from each side.** *Why next: a second opinion, one container at a time.*
```bash
docker port d02-draw
docker port d02-tools
```
```
80/tcp -> 0.0.0.0:8102
80/tcp -> [::]:8102
```
The first command shows the mapping. The second prints nothing: `d02-tools` never got a port.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The **host** side of `-p 8102:80` is shared by the whole laptop, and a host port can be bound by only one container (or program) at a time. `d02-draw` already held 8102, so Docker refused to start `d02-tools` and left it in `Created`. The container side, port 80, was never the problem: every container has its own private port 80, so it can repeat freely.
</details>

## 🔧 Fix it
What changed: only the number *before* the colon in line 2 (there are no files to `diff` here; the "file" is the command):
```
before:  docker run -d --name d02-tools -p 8102:80 corentinth/it-tools:2024.10.22-7ca5933
after:   docker run -d --name d02-tools -p 8202:80 corentinth/it-tools:2024.10.22-7ca5933
```
By hand: remove the stuck container (its name is taken), then run line 2 again on a free host port:
```bash
docker rm -f d02-tools
docker run -d --name d02-tools -p 8202:80 corentinth/it-tools:2024.10.22-7ca5933
```
Or run the shortcut, which does the same and prints both commands first:
```bash
./fix/fix.sh
```

## ✅ Verify it yourself
```bash
docker ps --filter name=d02- --format '{{.Names}}  {{.Ports}}'
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
- `docker ps --filter publish=PORT` finds who holds a port; `docker port NAME` shows a container's mappings; `docker inspect` shows what you asked for.
- When a port is taken, change the host number, not the app.

## 💎 Lifelong lesson
> Read the first error line slowly. It usually names the culprit.

## 🧹 Clean up
```bash
./cleanup.sh
```

## Next →
[D03](../03-votes-cant-reach-redis/README.md): *The voting booth is open, but every vote vanishes into thin air.*
