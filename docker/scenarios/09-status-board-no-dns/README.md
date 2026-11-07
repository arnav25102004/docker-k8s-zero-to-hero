# D09 · The status board says everything is down

*The status board says everything is down. Everything is up.*

⏱ 10 min · beginner · Excalidraw + IT-Tools + a tiny "Campus status board" · default bridge vs user-defined networks, container DNS

⬇️ First run downloads about 87 MB (Excalidraw 44 MB, IT-Tools 24 MB, Python 19 MB). Do it on good Wi-Fi, before the session. If you already did D02, D03, D05 or D08, most of it is cached.

On Windows, keep the repo inside WSL's Linux filesystem (not `C:\`): the board's script is mounted into a container from this folder.

## 📖 The story
It's fest week at the campus in Bengaluru. Your team runs a drawing board (Excalidraw) and a tools page (IT-Tools), and a small **status board** on the big screen that checks both every few seconds. Today the screen is a wall of red ❌. Meanwhile, the apps are running, and `docker ps` says so. Who is lying: the board, or Docker?

## 🧠 The concept: why, what, how
Containers get random IP addresses, and those change every time. So nobody wants to say "call 172.17.0.3"; you want to say "call `d09-draw`". Docker can do that: it runs a tiny **DNS server** (a phone book) that turns container names into IP addresses.

The catch: **the phone book only exists on networks you create yourself** (user-defined networks). The built-in **default `bridge`** network has no phone book at all. Containers there can only be reached by IP address.

Think of a hostel: on your own floor everyone knows each other by name. On the open ground, you only have phone numbers.

```
default bridge:        d09-board ──"d09-draw?"──▶ ❌ nobody to ask
user-defined d09-net:  d09-board ──"d09-draw?"──▶ Docker's phone book ──▶ 172.19.0.2 ✅
```

## 🏢 Where you'll meet this at work
- **Legacy setups** using `docker run --link`, the old way to fake name lookup (developer).
- **Scripts that run `docker run` without `--network`**: everything lands on the default bridge and names stop working (developer, platform team).
- **Docker Compose** quietly creates a network for every project, which is why names "just work" there until someone leaves Compose behind (everyone).

## 💥 Break it
```bash
cd break && ./break.sh
```
The room should see: the board at http://localhost:8109 (playground: the port 8109 URL) shows big red ❌ tiles for both apps, while all three containers are running.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Are the apps really down?** Look at the containers:
```bash
docker ps --filter name=d09-
```
```
CONTAINER ID   IMAGE                                    COMMAND                  CREATED        STATUS                           PORTS                                         NAMES
2d5af8fdaadb   python:3.12-alpine                       "python -u /board.py"    1 second ago   Up 1 second                      0.0.0.0:8109->8000/tcp, [::]:8109->8000/tcp   d09-board
350cabae942a   corentinth/it-tools:2024.10.22-7ca5933   "/docker-entrypoint.…"   1 second ago   Up 1 second                      80/tcp                                        d09-tools
a1f2bd69a60b   excalidraw/excalidraw:latest             "/docker-entrypoint.…"   1 second ago   Up 1 second (health: starting)   80/tcp                                        d09-draw
```
All three are `Up`. (Your IDs and times will differ; `d09-draw` says `health: starting` for a few seconds, then `healthy`.)

**2. What does the board itself say?**
```bash
docker logs --tail 4 d09-board
```
```
❌ d09-draw: [Errno -2] Name does not resolve
❌ d09-tools: [Errno -2] Name does not resolve
❌ d09-draw: [Errno -2] Name does not resolve
❌ d09-tools: [Errno -2] Name does not resolve
```
On most setups it says **Name does not resolve** (on some networks you may see a timeout instead). Either way it is not "connection refused": the board never even found out *where* the apps are.

<details><summary>💡 Hint</summary>
The board calls the apps by <b>name</b>. Who turns a name into an address? And do all Docker networks offer that service? Check which network these containers are on.
</details>

**3. Test the name lookup by hand,** from inside the board's container:
```bash
docker exec d09-board python -c "import socket;socket.gethostbyname('d09-draw')"
```
```
Traceback (most recent call last):
  File "<string>", line 1, in <module>
socket.gaierror: [Errno -2] Name does not resolve
```
Same kind of failure (the exact wording can differ on your setup), outside the board's own code. So it's the container's environment, not the board's script.

**4. Which network is the board on?**
```bash
docker inspect -f '{{json .NetworkSettings.Networks}}' d09-board
```
```
{"bridge":{"IPAMConfig":null,"Links":null,"Aliases":null,"DriverOpts":null,"GwPriority":0,"NetworkID":"4b29e5580d41d931f07651690afcea727d2c87401d2088ca9763d80b6a8c21b7", ... }
```
(shortened) The only network is called **`bridge`**: the default one. The other two containers are there too.

**5. What networks exist?**
```bash
docker network ls
```
```
NETWORK ID     NAME      DRIVER    SCOPE
4b29e5580d41   bridge    bridge    local
c40222f2df6f   host      host      local
b320b6c4e474   none      null      local
```
(Your list may show more networks.) Only Docker's three built-ins. Nobody ever created a network for this app.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

All three containers sit on the **default bridge**, which has **no DNS for container names**. The board asks for `d09-draw`, nobody can answer, and it reports ❌. The apps were never down; the board just couldn't find them.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: the two `board.py` files are identical, and the only difference is how the containers are networked. The `docker network` lines in each script:
```bash
diff ../break/board.py board.py && echo "board.py: identical"
grep -H "docker network" ../break/break.sh fix.sh
```
```
board.py: identical
fix.sh:docker network create --label z2h.scenario=d09 d09-net >/dev/null || die "Could not create the network d09-net."
fix.sh:docker network connect d09-net d09-draw || die "Could not connect d09-draw. Did you run break.sh first?"
fix.sh:docker network connect d09-net d09-tools || die "Could not connect d09-tools."
fix.sh:docker network connect d09-net d09-board || die "Could not connect d09-board."
```
`break.sh` has no network lines at all. By hand, it is four commands, and **no restarts**:
```bash
docker network create d09-net
docker network connect d09-net d09-draw
docker network connect d09-net d09-tools
docker network connect d09-net d09-board
```

## ✅ Verify it yourself
Open http://localhost:8109 (playground: the port 8109 URL). The tiles turn green within a few seconds.
```bash
docker logs --tail 2 d09-board
```
```
✅ d09-draw up
✅ d09-tools up
```
Now the same lookup that failed before:
```bash
docker exec d09-board python -c "import socket;print(socket.gethostbyname('d09-draw'))"
docker exec d09-board grep nameserver /etc/resolv.conf
```
```
172.19.0.2
nameserver 127.0.0.11
```
(Your IP may differ.) The name became an address. `127.0.0.11` is Docker's built-in phone book, which only appears on user-defined networks.
```bash
docker ps --filter network=d09-net --format '{{.Names}}' | sort
```
```
d09-board
d09-draw
d09-tools
```
`docker network inspect d09-net` shows the full details, including each container's IP.

## 🎯 Key takeaways
- The **default bridge has no DNS**: containers there can't find each other by name.
- A **user-defined network** gives every container on it a name (Docker's phone book at `127.0.0.11`).
- `docker network connect NETWORK CONTAINER` adds a running container to a network, with no restart.
- `docker inspect` on a container tells you which networks it is on; always check before blaming the app.

## 💎 Lifelong lesson
> Things can't talk until they share a network, and know each other's names.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
D10: Build your own QR code app. The file is right there. Docker says it doesn't exist.
