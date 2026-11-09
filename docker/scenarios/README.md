# 🔥 Docker break-and-fix scenarios

15 stage demos. Each one **breaks something on purpose**, the class investigates by hand, then a fix script repairs it. Every scenario has its own folder with a story, the concept, the commands to type, and takeaways.

> These are not the same as the labs D00–D11. Here **D01–D15 means scenario folders** in this directory.

## The lineup

| # | Scenario | App | Hook | ⬇️ First run |
|---|----------|-----|------|------|
| D01 | [Jupyter blinks… and it's gone](01-jupyter-vanishes/README.md) | Jupyter | *You click run, Jupyter blinks… and it's gone.* | 343 MB |
| D02 | [Two great apps, one door](02-port-clash/README.md) | Excalidraw + IT-Tools | *Two great apps. One door. Only one gets in.* | 68 MB |
| D03 | [The votes that vanish](03-votes-cant-reach-redis/README.md) | Cats vs Dogs API + Redis | *The voting booth is open, but every vote vanishes into thin air.* | 36 MB |
| D04 | [The password that isn't](04-vscode-wrong-password/README.md) | VS Code in the browser | *The settings file says `change-me-123`. VS Code says "Incorrect password". Who's lying?* | 380 MB |
| D05 | [One character](05-image-tag-typo/README.md) | IT-Tools | *One letter. That's all it takes to break a deploy.* | 24 MB |
| D06 | [No error, no goodbye](06-jupyter-oom-killed/README.md) | a small Python "AI trainer" (Compose) | *Your AI model was a few epochs into training. Then it vanished. No error. No goodbye.* | 19 MB |
| D07 | ["Permission denied"](07-jupyter-cant-save/README.md) | Jupyter | *Two hours of notebook work. You press Save. "Permission denied."* | 343 MB (as D01) + 2 MB |
| D08 | [Healthy app, sick label](08-it-tools-unhealthy/README.md) | IT-Tools | *The app works perfectly. Docker swears it's sick.* | 24 MB |
| D09 | [The status board says everything is down](09-status-board-no-dns/README.md) | Excalidraw + IT-Tools + a status board | *The status board says everything is down. Everything is up.* | 87 MB |
| D10 | [Build your own QR code app](10-qr-app-build-fails/README.md) | a QR code page on nginx | *The file is RIGHT THERE. Docker says it doesn't exist.* | 23 MB |
| D11 | [Priya's portfolio, on localhost only](11-portfolio-localhost-only/README.md) | a portfolio page (Python) | *It works inside. It's running. And nobody can see it.* | 19 MB |
| D12 | [The high score that vanished](12-high-score-lost-on-stop/README.md) | Dosa Dash game (Python) | *You beat the high score. The server restarts. Your name is gone.* | 19 MB + 2 MB |
| D13 | [The portfolio that disappears](13-portfolio-disappears/README.md) | a portfolio page on nginx | *The website is in the image. You can prove it. And it's gone.* | 23 MB |
| D14 | [The leaked API key](14-leaked-api-key/README.md) | Bengaluru weather widget (Python) | *You never pushed the key to GitHub. You pushed it inside the image.* | 19 MB |
| D15 | [Everything starts. Nothing works.](15-compose-start-order/README.md) | Dosa ratings board + PostgreSQL (Compose) | *Everything starts. Nothing works. Run it again… and it works?!* | 135 MB |

Scenario `NN` uses host port `81NN` (a second app, if any, uses `82NN`). The login for any app that has one is `change-me-123`. All images and sizes are in [IMAGES.md](IMAGES.md).

## How a session runs

Every command runs from the scenario folder (the one holding `break/`, `fix/` and `README.md`).

1. **Instructor explains**: read the story and the concept in the scenario's `README.md`.
2. **Break it**: the README first shows the commands to type by hand: `rm -rf work && cp -R break work`, then build and run (D06 onward: `docker compose -f work/compose.yaml up -d`; D06 adds `--build`). The one-line shortcut is `./break/break.sh`. It prints every Docker command it runs, exactly as you would type it.
3. **Investigate by hand**: the class types the commands from the README. `break.sh` never explains the cause, that is the class's job.
4. **Fix it**: `diff break/X fix/X` shows what changed. The class edits the files in `work/` and runs the build/run commands again. `./fix/fix.sh` is the safety net: it does the same and prints its commands too.
5. **Verify by hand**: the class checks it really works. `fix.sh` does not verify for you.
6. **Clean up**: `./cleanup.sh` resets everything, including `work/`.

`work/` is your own copy: edit it freely, the `break/` and `fix/` folders never change. Every `break.sh` cleans up first, so you can run it again and again.

## Platform notes

| Where | What to know |
|-------|--------------|
| macOS / Linux | Docker Desktop or Docker Engine. Nothing else to install. |
| Windows | **WSL2 is recommended.** Git Bash works if you first run `export MSYS_NO_PATHCONV=1` in that terminal (Git Bash otherwise rewrites paths like `/data` into Windows paths). On WSL, keep this repo **inside the Linux filesystem** (`~/…`), not under `/mnt/c/…`. Line endings stay LF (`.gitattributes` does this). |
| Play with Docker | Supported. Open the apps with the port badge that appears at the top. |
| Killercoda, iximiuz | Supported. Open the apps through the platform's "traffic / ports" link for `81NN`. |

Scripts need only `bash`, `docker`, `curl` and ordinary Unix tools. No `jq`.

From D06 on you need Docker Compose v2: check with `docker compose version`.

## 🆘 PANIC CARD (when something goes wrong on stage)

Stay calm. Nothing here can hurt the laptop. In this order:

1. **Reset the scenario:** `./cleanup.sh` (from the scenario folder; it also deletes `work/`). It is safe at any time, even if nothing is running.
2. **Look at what is running and where:** `docker ps --format '{{.Names}}  {{.Ports}}'`. A port clash names the holder.
3. **Run it again:** `./break/break.sh` again. It starts clean every time.
4. **Still odd? Reset everything:** `./labs.sh docker clean` from the repo root. It runs every scenario's `cleanup.sh`.

Docker not running? Start Docker Desktop, wait for the whale to settle, then step 3.

## Instructor preload checklist

- [ ] **The day before**, on good Wi-Fi: `./docker/scenarios/preload.sh`. It pulls every image in [IMAGES.md](IMAGES.md) (about 970 MB) and prints ✅/❌ per image and a total.
- [ ] **Then run every scenario once** (break, fix, cleanup), so you have seen each output on your own machine.
- [ ] On the morning: `docker ps -a --format '{{.Names}}' | grep -E '^d[01][0-9][-_]'` prints nothing (or run `./labs.sh docker clean`; hand-typed containers carry no label, so a label filter would miss them).

## Playground dry-run checklist

Tick each cell after you have run the whole scenario (break, fix, cleanup) on that platform. The build machine tested macOS (Docker Desktop, arm64) only.

| Scenario | Killercoda | iximiuz | Play with Docker | Linux | WSL2 | Git Bash |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|
| D01 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D02 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D03 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D04 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D05 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D06 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D07 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D08 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D09 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D10 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D11 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D12 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D13 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D14 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| D15 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

**Known platform-sensitive scenarios.** Look at these first:

- **D05 and D10 need Docker Hub reachable:** D05's lesson needs the registry to answer (offline it shows a DNS error instead of "not found"); D10 pulls nginx on first run.
- **D06 OOM:** the memory limit and exit code 137 behave the same on cgroup v1 and v2, but `docker inspect` / `docker stats` numbers differ a little. On Play with Docker and older hosts (cgroup v1) check that `OOMKilled` shows `true`.
- **D09 DNS error wording:** the exact message from the failed name lookup differs between Docker versions and base images. The idea (name not found on the default bridge) is the same.
- **D11 curl error wording:** "Connection refused" vs "Empty reply from server" depends on the curl and Docker version. Check what your screen shows before the class.
- **D13 bind mount path on WSL:** the repo must live in the Linux filesystem (`~/…`). From `/mnt/c/…` the mount can be slow or behave differently.
- **D14 BuildKit secrets:** needs BuildKit (the default in Docker 23 and newer). Older Docker on a playground may need `DOCKER_BUILDKIT=1`.
- **D15 Compose v2:** needs `docker compose` (the plugin, v2), not the old `docker-compose`. The columns of `docker compose ps` vary between versions.

Found a difference? Write it next to the scenario's README commands, so the next instructor knows.

➡️ Back to the [Docker track](../README.md)
