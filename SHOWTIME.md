# 🎤 SHOWTIME: The Instructor's Run-of-Show

> Deliver Docker & Kubernetes like a product launch. Every concept gets a **moment** the audience *sees* happen on the big screen, on their own phones, or both.
>
> This guide covers **what to run, what to say, and what the room experiences**. The labs hold the detail; this is the performance.

---

## 🎬 The 3 rules of the show
1. **Show, then explain.** Never define a concept before the audience has seen it happen. "What just happened?" is the best question in teaching.
2. **Make them predict.** Before every "wow", ask *"What do you think will happen?"*, and take a show of hands. Being surprised is what makes it stick.
3. **Their phones are part of the demo.** The Showdown app is a live vote. When *their* votes survive *your* chaos, they feel it.

## 🧰 Stage setup (the night before)
```bash
./scripts/check-prereqs.sh --pull      # everything cached: no Wi-Fi drama on stage
docker build -t z2h/api:1.0 apps/api && docker build -t z2h/frontend:1.0 apps/frontend
./scripts/load-image.sh z2h/api:1.0 z2h/frontend:1.0
```
- Terminal font **≥ 20pt**, dark theme. Browser zoom 125%.
- Two terminals side by side + browser on the right half of the screen.
- Find your laptop IP (`ipconfig getifaddr en0`) and write `http://<ip>:8080` on the whiteboard or slide, or turn it into a QR code.
- **Plan B for the network:** if the venue Wi-Fi blocks device-to-device traffic, turn on your phone hotspot, have 3–5 volunteers join it, and project their votes.

---

## PRELUDE: "Every change starts with Git" · 30–45 min · [Track 0](git/README.md)
1. **The ₹1 benne dosa** 🥞 *(G00 §1, G02)*. Read the owner/Lakshmi/Ravi dialogue, then live: `git blame menu.md` names the commit in one second, and `git revert` fixes it safely. Ask: *"How long would this take with menu_FINAL_really.docx?"*
2. **The ghee roast dosa price war** ⚔️ *(G05)*. Two volunteers, two laptops (or two terminals on the projector): both change the same line and both push. The room watches the conflict markers appear, then decides the price together.
3. **The Friday incident** 🚨 *(G07)*. `git bisect run` names the guilty commit among the suspects in about 3 seconds. Then: *"…and that tag becomes the Docker image you'll build after lunch."* That's your bridge into the Docker acts.

## ACT 0: "Why?" (foundations) · 30–45 min · [D00](docker/00-foundations/README.md)
Open with **stories, not commands**. Use the D00 diagrams as your slides.

1. **The broken phone** 📱 *(D00 §1)*. Ask: *"Same phone, different seller: what made the difference?"* Let them say "the packaging", then reveal the mapping: app = phone, image = package, container = unboxed phone.
2. **"It works on my machine!"** *(D00 §1)*. Perform the developer/tester/ops dialogue with two volunteers reading the lines. Everybody laughs, and everybody has lived it.
3. **"Containers didn't start with Docker"** 🧒 *(D00 §3)*. Open with *"Who shares a room with a brother or sister?"*, then tell the story with the timeline slide: curtain (1979) → walls → snack limit → ready-made room (Docker, 2013) → library + hotel manager → standard box → direct line. Land the punchline: *"Docker didn't invent containers; it made them so easy a student can do it in one command."* Have pairs teach the 7-step chain back to each other in 60 seconds, then go straight to `docker run hello-world`.
4. **Houses vs apartments** 🏠🏢 *(D00 §4)*. Then the proof: `uname -r` in Alpine and in Ubuntu prints **the same kernel**. Let the room react.
5. **Sunday breakfast at The Rameshwaram Cafe** 🥞 *(D00 §5)*. Counter, token, head chef, fridge, cold store, tawa. Then `docker version` shows Engine, containerd and runc: the kitchen staff, for real.
6. **"Are you PID 1?"** *(D00 §7)*. `docker run --rm alpine ps` shows that the container believes it's alone in the world. Then `docker top` shows the host's view: two views of one process.

Close Act 0 with: *"Now that you know what's inside the box, let's play with some boxes."*

> For the Kubernetes half, open Act 3 the same way with [K00](kubernetes/00-foundations/README.md): the 3 a.m. pager dialogue, the container-port diagram, and the "try to out-delete the controller" demo.

## ACT 1: "The Box" (Docker basics) · 45 min

### Scene 1: The 3-second miracle 🍄 *(Lab D01)*
**Say:** *"Raise your hand if you've ever spent a whole day installing software just to get something to run."* (hands go up) *"Watch this."*
```bash
docker run -d --rm -p 8600:8080 pengbai/docker-supermario
```
Open http://localhost:8600 and **play Mario on the projector**. Hand the keyboard to a volunteer.

**Then reveal:** *"That's a Java web server, a game engine, and an operating system's worth of files. I installed none of it. It arrived in a **box**, and the box runs the same on every machine on Earth."*

Quick-fire arcade (one line each, rapid): `nyancat` → `cmatrix` → `cowsay | lolcat`. Each one appears and **vanishes**: *"Containers are disposable. That's a feature."*

### Scene 2: Meet the Showdown 🐱🐶 *(Lab D03)*
```bash
docker run -d --name showdown -p 8080:8080 z2h/api:1.0
```
Put the URL up: **"Everyone: phones out. Vote."** Watch the bars move live.

**Point at the "served by" card:** *"That name is the container. One box is serving all of you right now."*

### Scene 3: The cliffhanger 💀 *(Lab D03 Step 11)*
**Ask:** *"I'm going to replace this container with a fresh copy. Same image, same code. What happens to your votes?"* (take a show of hands)
```bash
docker rm -f showdown && docker run -d --name showdown -p 8080:8080 z2h/api:1.0
```
Refresh. **Every vote is gone.** Let the silence land. *"Where did they go? Hold that thought. We'll fix it in Act 2."*

### Scene 4: One image, infinite apps 🎩 *(Lab D04 Step 3)*
Launch Bengaluru Breakfast Battle 🥞, Editor Wars 🟢, and Best Weekend Spot 🌳 on three ports, side by side. *"Same image. Zero rebuilds. Only configuration changed. This is how one image goes from your laptop to production."*

---

## ACT 2: "The Team" (multi-container) · 45 min

### Scene 5: Votes that survive 💾 *(Lab D06 Step 6)*
Add Redis on a volume. The badge turns green: *"votes in Redis"*. Get the room voting, then **destroy both containers**. Recreate them. Refresh. **Votes intact.** *"The containers died. The data didn't. Separate what you run from what you keep."*

### Scene 6: Three tiers by hand, then load balancing 🧱 *(Lab D07 Steps 4–5)*
Add `api2` and `api3`. **The Pod wall lights up with three colours.** Kill one with `docker rm -f api2`: its tile fades to grey, and **the failed counter stays at 0**. *"One server just died, and none of you noticed."*

### Scene 7: One command to rule them all 🚀 *(Lab D08)*
```bash
cd docker/08-compose && docker compose up -d --build
docker compose up -d --scale api=5 && docker compose restart frontend
```
**Five tiles.** Now let the audience hit **💥 Crash this server** from their phones. Chaos, live. The restart policy brings them back, and the failed counter barely moves.

### Scene 8: "One more thing…" 🦄 *(Lab D08 Step 8)*
Set it up slowly: *"We have Cats. We have Dogs. But there's something the audience has been asking for…"*
Add `unicorns` to `.env`, then `docker compose up -d`. **The banner flashes, 🦄 appears on every phone.** Old votes are still there.

---

## ACT 3: "The Fleet" (Kubernetes) · 90 min

### Scene 9: Meet the captain ☸️ *(Labs K01–K02)*
Keep this short and visual: `kubectl get nodes`, `kubectl get pods -A`. *"The control plane runs on itself. Kubernetes is made of Kubernetes."* Walk through the "desired state" idea: *"You don't tell Kubernetes what to **do**. You tell it what you **want**. It works out the rest, forever."*

### Scene 10: Self-healing you can see 🩹 *(Lab K04)*
Deploy the Showdown with 3 replicas, phones voting.
**Ask:** *"I'm going to delete every server. All of them. What happens?"*
```bash
kubectl delete pod -l app=api --wait=false
```
Grey tiles 🪦, then new tiles 🆕 within seconds. *"I didn't restart anything. A controller noticed reality didn't match my wish, and fixed reality."*
Then `kubectl scale deployment api --replicas=10`. **The wall fills up.** 🎆

**Plant the cliffhanger:** *"Notice the vote counts jumping around? Ten servers, ten different memories…"* → fixed in K05 with Redis + DNS.

### Scene 11: The break-in 💥 *(Lab K05 Step 6)*
Typo the Service selector live. **The whole room's app goes red.** Pods: all Running. *"Everything is green in the dashboard, and every user is down. Welcome to production."* Fix it, and the room turns green again.

### Scene 12: THE KEYNOTE MOMENT 🎤 *(Lab K06)*
This is the one they'll remember.
1. Phones voting. Point at **failed: 0**.
2. *"In the old days, releasing a new version meant a maintenance window. 2 a.m. Filter coffee. Prayers."*
3. *"Today, I'm going to replace every server you're talking to, with a brand-new version, **while you're voting**."*
4. Pause. *"And one more thing…"*
```bash
kubectl set env deployment/api APP_VERSION=2.0.0 VOTE_OPTIONS="cats:🐱:Cats,dogs:🐶:Dogs,unicorns:🦄:Unicorns"
```
5. Banner. 🦄 Unicorns appear on every phone. Old and new Pods mix on the wall, then the old ones are gone. **Failed: still 0.**
6. *"Every server replaced. Nobody noticed. That's Kubernetes."* 🎤⬇️

**Encore, the disaster that wasn't:** ship a broken image tag. The rollout stalls, users are fine, `kubectl rollout undo`. *"Friday-evening deploys, solved."*

### Scene 13: Change the poll for the whole room *(Lab K07 Step 3)*
Patch the ConfigMap to **The Great Bengaluru Food Fight** 🥞🍛☕🥙. Nothing changes… *"Why not?"* (env vars are read at start) → `kubectl rollout restart`. The room flips to food, with zero downtime.

### Scene 14: The canary 🐤 *(Lab K12, if time allows)*
Gateway API, 90/10 split. **The 🦄 card flickers in and out** as 1 in 10 requests hits v2. Dial it to 50, then 100. *"That's how Netflix and Google ship: a little traffic first, then more."*

### Scene 15: Watch it grow 📈 *(Lab K13)*
Start the load generator. Nobody touches the keyboard. **The Pod wall grows by itself.**

---

## FINALE: "The Gauntlet" 🏆 *(Lab K18 Part 3)* · 30 min
Deploy the hardened capstone. Split the room into teams; each team gets **one** chaos experiment from the table, and everyone else predicts the outcome before it runs. Score it on the live health card: **every failed request is a point lost.**

Close with the checklist on screen: *"Every line on this list is something you **did** today. That's not zero anymore. That's hero."*

---

## 🧯 When things go wrong on stage (they will, and that's a gift)
| Problem | Turn it into a lesson |
|---|---|
| Image pull is slow | *"This is why we pre-pull and why image size matters"* → preview of Lab D05. Instructor: run `docker/scenarios/preload.sh` (Kubernetes: `kubernetes/scenarios/preload.sh`) the day before ([Docker checklist](docker/scenarios/README.md), [Kubernetes checklist](kubernetes/scenarios/README.md#instructor-preload-checklist)) |
| Pod stuck `Pending` | Run `kubectl describe pod` live: *"Let's debug it together"* → [scenario S1.1](kubernetes/scenarios/1-architecture-and-pod-lifecycle/1-excalidraw-pending/README.md) |
| A typo breaks something | Leave it! Ask the room to find it. Best teaching moment of the day. |
| Phones can't connect | Hotspot plan B, or `kubectl port-forward --address 0.0.0.0`, or demo solo and use the curl voting loop |
| Laptop dies | Killercoda: the whole course runs in a browser |

## 🗓️ Suggested formats
| Format | Cover |
|---|---|
| **3-hour keynote workshop** | Act 0 (short), Scenes 1–3, 5–7, 9–12, then the Gauntlet (demo-led, audience votes) |
| **1 day hands-on** | D01–D08, K01–K08, 4 break-and-fix scenarios each ([Docker ones](docker/scenarios/README.md), [Kubernetes ones](kubernetes/scenarios/README.md)) |
| **2 days, zero to hero** | Day 1: Git G00–G06 (morning) + Docker labs D00–D08 + [break-and-fix scenarios](docker/scenarios/README.md) 01–05. Day 2: K00–K12 + [Kubernetes break-and-fix scenarios](kubernetes/scenarios/README.md) |
| **3 days, complete** | Day 1: Track 0 Git + G-scenarios. Day 2: Track 1 Docker + [Docker scenarios](docker/scenarios/README.md). Day 3: Track 2 Kubernetes + [Kubernetes scenarios](kubernetes/scenarios/README.md) |
| **4-hour Kubernetes workshop (college syllabus)** | Hour 1 to 2: the 30 [scenarios](kubernetes/scenarios/README.md), six sections of five, 4 minutes each, non-stop. Hour 3 to 4: the section exercises, the finale (S6.x5) and the two [projects](kubernetes/projects/README.md) |
| **Semester course** | One lab per session + one troubleshooting scenario as homework |
