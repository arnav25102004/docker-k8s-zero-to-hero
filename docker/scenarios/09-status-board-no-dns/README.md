# D09 · The status board says everything is down

*The status board says everything is down. Everything is up.*

⏱ 15 min · beginner · Excalidraw + IT-Tools + a tiny "Campus status board" · `compose.yaml`, container names, `docker compose config`, `docker network inspect`

⬇️ First run downloads about 87 MB (Excalidraw 44 MB, IT-Tools 24 MB, Python 19 MB). Do it on good Wi-Fi, before the session. If you already did D02, D03, D05 or D08, most of it is cached. Our own board image adds only a few KB on top of Python.

## 📖 The story
It's fest week at the campus in Bengaluru. Your team runs a drawing board (Excalidraw), a tools page (IT-Tools), and a small **status board** on the big screen that checks both every few seconds. Today the screen is a wall of red ❌. Meanwhile the apps are running, and Docker says so. Priya wrote the `compose.yaml` that starts all three. Who is lying: the board, or Docker?

## 🧠 The concept: why, what, how
Containers get IP addresses, and those change every time. So nobody wants to say "call 172.17.0.3"; you want to say "call `draw`". Docker can do that: it can run a tiny **DNS server** (a phone book) that turns names into IP addresses.

A **`compose.yaml`** is a file that writes down how to run several containers together: which image, which ports, which network. `docker compose up -d` reads it and starts everything; `docker compose config` prints what Compose *understood* from it. Each service in the file (`draw`, `tools`, `board`) becomes a container named `d09-<service>-1`, because the file says `name: d09`.

Think of a hostel: on your own floor everyone knows each other by name. On the open ground, you only have phone numbers.

One more plus of Compose: the Excalidraw image reference is long (`latest@sha256:` and 64 characters). In the file it is written **once**, and nobody ever types it.

## 🏢 Where you'll meet this at work
- **Every Compose project**: the web service reaches the database at the hostname `db`, never at an IP (developer).
- **Kubernetes Services**: your app calls `http://payments`, and the cluster answers with the right address. Same idea, bigger phone book (SRE, platform team).
- **A hard-coded IP in a config file** that worked yesterday and is wrong after a restart (everyone).

## 💥 Break it
Stay in this scenario's folder (`docker/scenarios/09-status-board-no-dns`) for everything below. Copy the files you will work on into a scratch folder `work/`, then let Compose build the board and start the three services:
```bash
rm -rf work && cp -R break work
docker compose -f work/compose.yaml up -d
```
Or use the one-line shortcut, which prints every Docker command before it runs it, exactly as above:
```bash
./break/break.sh
```
```
✅ Scenario d09 cleaned up
▶ $ rm -rf work && cp -R break work
▶ $ docker compose -f work/compose.yaml up -d
 Image d09-board:1.0 Building
... (shortened: Docker's build output) ...
 Container d09-board-1 Started
⏳ Waiting for the status board to report . ✔ ready
```
`work/` is your own copy (git ignores it), so you can edit it freely; the shortcut recreates it fresh every time.

Laptop: open http://localhost:8109. Playground: open the port 8109 URL. The board shows big red ❌ tiles for both apps.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Are the apps really down?** Start with the simplest question: what is running?
```bash
docker compose -f work/compose.yaml ps
```
```
NAME          IMAGE                                                                                                  COMMAND                  SERVICE   CREATED         STATUS                            PORTS
d09-board-1   d09-board:1.0                                                                                          "python -u /board.py"    board     5 seconds ago   Up 4 seconds                      0.0.0.0:8109->8000/tcp, [::]:8109->8000/tcp
d09-draw-1    excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9   "/docker-entrypoint.…"   draw      5 seconds ago   Up 4 seconds (health: starting)   80/tcp
d09-tools-1   corentinth/it-tools:2024.10.22-7ca5933                                                                 "/docker-entrypoint.…"   tools     5 seconds ago   Up 4 seconds                      80/tcp
```
All three are `Up`. (`draw` says `health: starting` for a few seconds, then `healthy`.)

**2. What does the board itself say?** It is the one complaining, so read its log.
```bash
docker compose -f work/compose.yaml logs --tail 4 board
```
```
board-1  | ❌ draw: [Errno -2] Name does not resolve
board-1  | ❌ tools: [Errno -2] Name does not resolve
board-1  | ❌ draw: [Errno -2] Name does not resolve
board-1  | ❌ tools: [Errno -2] Name does not resolve
```
On most setups it says **Name does not resolve** (the exact wording can differ on yours). It is not "connection refused": the board never even found out *where* the apps are.

<details><summary>💡 Hint</summary>
The board calls the apps by <b>name</b>. Who turns a name into an address? Does every Docker network offer that service? Look at which network these containers are on, and at what the compose file says about it.
</details>

**3. Test the name lookup by hand,** from inside the board's container. `getent hosts` asks the container's own resolver, the same one the board's code uses.
```bash
docker compose -f work/compose.yaml exec board getent hosts draw ; echo "exit code: $?"
```
```
exit code: 2
```
No answer at all (exit code 2 = "name not found"). Same failure, outside the board's own code. So it is the container's environment, not the script.

**4. What did I write?** Now read the file Docker was given.
```bash
cat work/compose.yaml
```
```
# D09: three services. The board checks "draw" and "tools" by their service names.
name: d09

services:
  draw:
    # Excalidraw, pinned to one exact version. It is written once, right here,
    # so nobody has to type this long reference.
    image: excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9
    network_mode: bridge

  tools:
    image: corentinth/it-tools:2024.10.22-7ca5933
    network_mode: bridge

  board:
    build: .
    image: d09-board:1.0
    pull_policy: build
    ports:
      - "8109:8000"
    network_mode: bridge
    depends_on:
      - draw
      - tools
```
Each service has a line `network_mode: bridge`. Keep that in mind.

**5. What did Compose understand?** `config` prints the file after Compose has read it.
```bash
docker compose -f work/compose.yaml config
```
```
name: d09
services:
  board:
    build:
      context: .../docker/scenarios/09-status-board-no-dns/work
      dockerfile: Dockerfile
    depends_on:
      draw:
        condition: service_started
        required: true
      tools:
        condition: service_started
        required: true
    image: d09-board:1.0
    network_mode: bridge
    ports:
      - mode: ingress
        target: 8000
        published: "8109"
        protocol: tcp
    pull_policy: build
  draw:
    image: excalidraw/excalidraw:latest@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9
    network_mode: bridge
  tools:
    image: corentinth/it-tools:2024.10.22-7ca5933
    network_mode: bridge
```
(shortened: the `context:` path is yours.) Look at what is **missing**: there is no `networks:` section at all, and no network called `d09_default`. Compose normally adds one. Remember this for after the fix.

**6. What networks exist, and who is on `bridge`?**
```bash
docker network ls
docker network inspect bridge -f '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}' | grep d09
```
```
NETWORK ID     NAME      DRIVER    SCOPE
4b29e5580d41   bridge    bridge    local
c40222f2df6f   host      host      local
b320b6c4e474   none      null      local
d09-board-1 172.17.0.6/16
d09-tools-1 172.17.0.4/16
d09-draw-1 172.17.0.5/16
```
(shortened: other networks on this machine omitted; yours may list more. The IPs will differ.) Docker's three built-in networks, and no `d09_default`. All three of our containers sit on the one called **`bridge`**: the default network.

**7. Are the apps alive, then?** Skip the name, and call the IP address of `d09-tools-1` straight from the board. Use *your* IP from step 6:
```bash
docker compose -f work/compose.yaml exec board python -c "import urllib.request as u;print(u.urlopen('http://172.17.0.4').status)"
```
```
200
```
`200 OK`. IT-Tools is up and reachable. Only the name fails.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

`network_mode: bridge` puts each container on Docker's built-in **default bridge** network instead of the project network Compose would normally create. Docker has two kinds of bridge networks:

- The **default `bridge`** has **no phone book**. Containers there can only reach each other by IP address, and Compose does not give them names.
- A **user-defined network** (Compose makes one called `d09_default`) has a built-in DNS server at `127.0.0.11`. Every service is reachable by its service name.

The board asked for `draw`, nobody could answer, and it reported ❌. The apps were never down.
</details>

## 🔧 Fix it
The fix is to delete three lines. See them first:
```bash
diff break/compose.yaml fix/compose.yaml
```
```
9d8
<     network_mode: bridge
13d11
<     network_mode: bridge
21d18
<     network_mode: bridge
```
By hand: open `work/compose.yaml` in any editor (VS Code, nano, Notepad) and delete the three `network_mode: bridge` lines. Or, on macOS/Linux/Git Bash: `sed -i.bak '/network_mode/d' work/compose.yaml && rm work/compose.yaml.bak`. Then run `up -d` again. Compose notices the containers no longer match the file, **recreates** them, and puts them on a new project network:
```bash
docker compose -f work/compose.yaml up -d
```
```
 Image d09-board:1.0 Building
 Image d09-board:1.0 Built
 Network d09_default Creating
 Network d09_default Created
 Container d09-draw-1 Recreate
 Container d09-tools-1 Recreate
 Container d09-draw-1 Recreated
 Container d09-tools-1 Recreated
 Container d09-board-1 Recreate
 Container d09-board-1 Recreated
 Container d09-tools-1 Starting
 Container d09-draw-1 Starting
 Container d09-tools-1 Started
 Container d09-draw-1 Started
 Container d09-board-1 Starting
 Container d09-board-1 Started
```
(shortened: Compose may print some lines twice, and the build output is left out.) Or run `./fix/fix.sh`, which does the same: it drops the fixed files into a fresh `work/`, then prints and runs that exact `docker compose -f work/compose.yaml up -d`.
```bash
./fix/fix.sh
```
Either way you end in the same place: containers `d09-draw-1`, `d09-tools-1`, `d09-board-1` on the network `d09_default`.

## ✅ Verify it yourself
Open http://localhost:8109 (playground: the port 8109 URL). The tiles turn green within a few seconds.
```bash
docker compose -f work/compose.yaml logs --tail 2 board
```
```
board-1  | ✅ draw up
board-1  | ✅ tools up
```
Now the same lookup that failed before, and the resolver it used:
```bash
docker compose -f work/compose.yaml exec board getent hosts draw
docker compose -f work/compose.yaml exec board grep nameserver /etc/resolv.conf
```
```
172.19.0.3        draw  draw
nameserver 127.0.0.11
```
(Your IP may differ.) The name became an address. `127.0.0.11` is Docker's built-in phone book. Now who is on the new network?
```bash
docker network inspect d09_default -f '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
```
```
d09-board-1 172.19.0.4/16
d09-tools-1 172.19.0.2/16
d09-draw-1 172.19.0.3/16
```
And `docker compose -f work/compose.yaml config` now has what was missing before: a `networks:` section.
```
    networks:
      default: null
...
networks:
  default:
    name: d09_default
```
(shortened: only the new lines are shown.) We did not write a network anywhere. Compose created it because we stopped opting out.

## 🎯 Key takeaways
- The **default `bridge`** has no DNS: containers there can only find each other by IP. A **user-defined network** gives every container a name (Docker's phone book at `127.0.0.11`).
- Compose creates a user-defined network per project (`d09_default`) automatically, so service names just work. `network_mode: bridge` opts out of it.
- Read the file (`cat compose.yaml`), then read what Compose understood (`docker compose config`), then what Docker did (`docker network inspect`).
- Edit the file, run `docker compose up -d` again: Compose recreates only what no longer matches.
- Long references like the Excalidraw `@sha256:` pin live in one file, written once.

## 💎 Lifelong lesson
> Things can't talk until they share a network, and know each other's names.

## 🧹 Clean up
```bash
./cleanup.sh
```
This removes the three containers, the network `d09_default`, the `d09-board:1.0` image and your `work/` folder.

## Next →
[D10](../10-qr-app-build-fails/README.md): Build your own QR code app. The file is right there. Docker says it doesn't exist.
