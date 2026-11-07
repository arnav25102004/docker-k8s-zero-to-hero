# Docker Break · Investigate · Fix Scenarios (batch 1 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `docker/troubleshooting/` (10 scripted scenarios) with `docker/scenarios/`: 15 stage-ready break/fix scenarios built on apps people love, each with `README.md`, `cleanup.sh`, `break/` and `fix/`.

**Architecture:** One folder per scenario. A shared `docker/scenarios/_lib.sh` keeps each script short and readable on a projector. An automated test harness (`tests/scenarios/docker.sh`, developer-only, never used in class) drives break → assert broken → fix → assert fixed → cleanup → assert clean, twice per scenario. Each scenario's assertions live in `tests/scenarios/docker/NN.sh`. In class, the instructor runs the scripts and the investigation/verification commands by hand.

**Tech Stack:** bash, Docker Engine 25+ with BuildKit and Compose v2, `curl`. Public multi-arch images only, plus one image built locally from `apps/api` (Cats vs Dogs).

**Spec:** `docs/superpowers/specs/2026-11-07-break-fix-scenarios-design.md` (read §3, §4, §5, §10, §11 before starting).

**Batches:** this plan covers batch 1 (Docker 01–15). Kubernetes 01–15 and 16–30 get their own plans after this batch ships. `kubernetes/troubleshooting/` and the `k8s` parts of `labs.sh` are **not touched** in this batch.

**Commits:** this repo's owner approves every commit and push ("Commit & push"). Do **not** commit during tasks. The final task stops and asks.

## Global Constraints

- Scripts: `bash`, shebang `#!/usr/bin/env bash`, `set -u` (no `set -e` in `cleanup.sh`), executable (mode 755), `shellcheck -S warning` clean.
- Allowed tools in scripts: `docker`, `docker compose`, `curl`, `grep`, `sed`, `awk`, `sleep`, `printf`, `cat`, `mkdir`, `rm`. Not allowed: `jq`, `envsubst`, `timeout`, GNU-only flags, `sed -i` without a backup suffix, `lsof`/`ss` as hard requirements (optional fallbacks only).
- Paths: scripts resolve everything relative to their own location (`$(cd "$(dirname "$0")" && pwd)`), so they work from any working directory.
- Naming: every container, network, volume, compose project and locally built image of scenario NN is prefixed `dNN-` (compose project `dNN`). Everything also carries the label `z2h.scenario=dNN` (images via `docker build --label`).
- Ports: scenario NN publishes host port `81NN`; a second app in the same scenario uses `82NN`. Bind all interfaces (no `127.0.0.1:` prefix) so playground URLs work.
- Logins: any app with a password uses `change-me-123`.
- Images: only images with linux/amd64 **and** linux/arm64 builds, pinned to an exact tag (pin the newest stable tag that has both; record it in `docker/scenarios/IMAGES.md`). Heavy images are limited to Jupyter `quay.io/jupyter/base-notebook` (D01, D06, D07) and VS Code `codercom/code-server` (D04); everything else ≤ ~160 MB.
- Line endings: LF, enforced by `.gitattributes` (`*.sh text eol=lf`, `*.yaml text eol=lf`, `*.yml text eol=lf`, `Dockerfile text eol=lf`).
- README follows spec §5's 13-part template exactly, in that order, about 1–2 screens, keynote tone, Bengaluru and college flavour where natural.
- `break.sh` never diagnoses; `fix.sh` never verifies. Both end by printing what to type next.

## Review Focus

1. **A scenario port is held by something else** (another app, or a container from an older scenario): `break.sh` must stop with a message naming the holder and how to free it, not a raw Docker error. Pinned by `test_port_busy` in Task 1.
2. **`break.sh` run twice in a row, or after `fix.sh`:** the second run must reproduce the same failure, because `break.sh` calls `cleanup.sh` first. Pinned by the harness's double cycle (Task 1) and run for every scenario.
3. **Image not present locally (first run on venue Wi-Fi):** the scenario must still work and say it's downloading. Pinned by `test_first_pull_message` in Task 1 (uses `busybox:1.36`).
4. **Scripts run from an unexpected working directory**, e.g. `bash docker/scenarios/06-…/break/break.sh` from the repo root, or from inside `fix/`: same behaviour. The harness always runs from the repo root, and `test_any_cwd` in Task 1 runs one scenario from `/tmp`.
5. **Docker daemon not running:** every script prints one friendly line ("Docker isn't running: start Docker Desktop…") and exits 1. Pinned by `test_no_daemon_message` in Task 1 (simulated with `DOCKER_HOST=unix:///nonexistent.sock`).

---

## File Structure

```
.gitattributes                                   (create)  LF rules
docker/scenarios/
├── README.md              index: lineup, session flow, platform notes, panic card,
│                          instructor preload checklist, playground dry-run checklist
├── IMAGES.md              pinned image tags, sizes, which scenarios use them
├── _lib.sh                shared helpers (Task 1)
├── preload.sh             pulls every image in IMAGES.md, prints ✅/❌
├── 01-jupyter-vanishes/            ├── README.md ├── cleanup.sh ├── break/ └── fix/
├── 02-port-clash/
├── 03-votes-cant-reach-redis/
├── 04-vscode-wrong-password/
├── 05-image-tag-typo/
├── 06-jupyter-oom-killed/
├── 07-jupyter-cant-save/
├── 08-it-tools-unhealthy/
├── 09-status-board-no-dns/
├── 10-qr-app-build-fails/
├── 11-portfolio-localhost-only/
├── 12-high-score-lost-on-stop/
├── 13-portfolio-disappears/
├── 14-leaked-api-key/
└── 15-compose-start-order/
tests/scenarios/
├── lib.sh                 harness helpers: assert_*, run_cycle
├── docker.sh              harness entry: ./tests/scenarios/docker.sh [NN ...]
├── docker-selftest.sh     Review Focus tests for _lib.sh behaviour
└── docker/NN.sh           per-scenario: broken() and fixed() assertions
```
Removed at the end: `docker/troubleshooting/` (content reused via `git mv` where a scenario is ♻️).

---

### Task 1: Shared library, harness and repo plumbing

**Files:**
- Create: `.gitattributes`, `docker/scenarios/_lib.sh`, `tests/scenarios/lib.sh`, `tests/scenarios/docker.sh`, `tests/scenarios/docker-selftest.sh`

**Interfaces:**
- Produces, in `docker/scenarios/_lib.sh`. It is sourced with an absolute path built from the script's own location: from `break/` and `fix/` scripts, `source "$(cd "$(dirname "$0")/../.." && pwd)/_lib.sh"`; from `cleanup.sh`, `source "$(cd "$(dirname "$0")/.." && pwd)/_lib.sh"`.
  - `say MSG` (cyan ▶), `ok MSG` (green ✔), `warn MSG` (yellow ⚠), `die MSG` (red ✖, exit 1)
  - `need_docker`: if `docker info` fails, `die "Docker isn't running. Start Docker Desktop (or the Docker service) and try again."`
  - `port_free PORT`: returns 0 if free. Otherwise prints which container publishes it (`docker ps --filter publish=PORT --format '{{.Names}}'`), or says "another program on your computer", plus the fix line (`docker rm -f <name>` or "pick another port / close that program"), and returns 1. Detection: a container check first, then `curl -s -o /dev/null --max-time 1 http://127.0.0.1:PORT` (any answer = busy).
  - `ensure_image IMAGE SIZE_TEXT`: if `docker image inspect IMAGE` fails, `say "⬇️  Downloading IMAGE (SIZE_TEXT, first time only)…"` and `docker pull IMAGE` (progress visible).
  - `wait_for DESCRIPTION SECONDS COMMAND...`: polls the command every second up to SECONDS (a bash loop, no `timeout`). Prints a dot per second, then `ok`, or `warn "… still not ready after Ns"` and returns 1.
  - `scenario_cleanup ID` (ID like `d06`): removes containers, networks and volumes with label `z2h.scenario=ID`, runs `docker compose -p ID down -v --remove-orphans` if a compose project exists, removes images with label `z2h.scenario=ID`, and is silent. It never fails, then prints `✅ Scenario ID cleaned up`.
  - `show_next MSG...`: prints a "👀 What you should see now" / "👉 Next" block.
- Produces, in `tests/scenarios/lib.sh`: `assert_eq ACTUAL EXPECTED MSG`, `assert_contains HAYSTACK NEEDLE MSG`, `assert_cmd_fails MSG CMD...`, `http_code URL` (prints the code via `curl -s -o /dev/null -w '%{http_code}' --max-time 5`), `container_state NAME` (prints `{{.State.Status}}`), `run_cycle DIR ID` (cleanup → break → `broken` → fix → `fixed` → cleanup → assert nothing with label `z2h.scenario=ID` remains; run twice; fail fast with the step name).
- Produces, in `tests/scenarios/docker.sh`: usage `./tests/scenarios/docker.sh [NN ...]` (no args = all present scenarios). It sources `tests/scenarios/docker/NN.sh` (which must define `broken()` and `fixed()`), calls `run_cycle`, and prints a ✅/❌ summary. Exit code is non-zero on any failure.

- [ ] **Step 1: Write `tests/scenarios/docker-selftest.sh` with the five Review Focus tests**
  - `test_port_busy`: start `busybox:1.36` as `zz-portholder` publishing `8199:80` (`httpd` via `busybox httpd -f -p 80`). Source `_lib.sh` and run `port_free 8199`. Assert it returns 1 and its output contains `zz-portholder` and `docker rm -f zz-portholder`. Remove the holder.
  - `test_first_pull_message`: `docker rmi busybox:1.36` (ignore errors), then run `ensure_image busybox:1.36 "2 MB"`. Assert the output contains `Downloading busybox:1.36` and the image exists afterwards.
  - `test_wait_for`: `wait_for "true thing" 3 true` returns 0; `wait_for "false thing" 2 false` returns 1 and prints `still not ready after 2s`.
  - `test_no_daemon_message`: `DOCKER_HOST=unix:///nonexistent.sock bash -c 'source docker/scenarios/_lib.sh; need_docker'`. Assert exit 1 and output contains `Docker isn't running`.
  - `test_any_cwd`: deferred. Its body is added in Task 2: `(cd /tmp && bash "$REPO/docker/scenarios/02-port-clash/break/break.sh")`, then assert `container_state d02-draw` = `running`, then run that scenario's `cleanup.sh`.
  - `test_cleanup_idempotent`: on a clean system, `scenario_cleanup d99` twice. Both exit 0 and print `✅ Scenario d99 cleaned up`.
- [ ] **Step 2: Run it and watch it fail.** Run `bash tests/scenarios/docker-selftest.sh`. Expected: failures (`_lib.sh` doesn't exist).
- [ ] **Step 3: Implement `docker/scenarios/_lib.sh` and `tests/scenarios/lib.sh` with the interfaces above, plus `tests/scenarios/docker.sh`**
- [ ] **Step 4: Run the self-test.** Run `bash tests/scenarios/docker-selftest.sh`. Expected: all tests ✅ except `test_any_cwd` reported as `SKIP (needs scenario 02)`.
- [ ] **Step 5: Create `.gitattributes`** with the LF rules from Global Constraints. Run `git add --renormalize -n .` and confirm no `.sh`/`.yaml` file is listed as changing EOLs unexpectedly.
- [ ] **Step 6: Run shellcheck.** `shellcheck -S warning docker/scenarios/_lib.sh tests/scenarios/*.sh`. Expected: no output.

---

### Scenario tasks (Tasks 2–16): the common recipe

Every scenario task follows these steps. Each task lists only what is specific to it.

- [ ] **Step 1: Write `tests/scenarios/docker/NN.sh`** with `broken()` and `fixed()`, using the task's **Assert broken** / **Assert fixed** lines verbatim.
- [ ] **Step 2: Run `./tests/scenarios/docker.sh NN`.** Expected: ❌ (the scenario folder doesn't exist yet).
- [ ] **Step 3: Build the scenario.**
  - If ♻️, first run `git mv docker/troubleshooting/<old> docker/scenarios/<new>`, then reshape it.
  - Create `cleanup.sh` (calls `scenario_cleanup dNN` plus any extra removals the task lists).
  - Create `break/break.sh`:
    1. `need_docker`
    2. run `../cleanup.sh`
    3. `port_free` for every port the scenario uses (`die` if busy)
    4. `ensure_image` for every image
    5. create the failure
    6. `wait_for` until the failure is visible
    7. `show_next` with what to see and the first investigation command
  - Create `fix/fix.sh`:
    1. apply the corrected setup
    2. `wait_for` healthy
    3. `show_next "✅ Fixed. Now verify it yourself:" <first verify command>`
  - Put any files in `break/` and `fix/` (the `fix/` copy is the corrected version, so `diff -r break fix` shows the change).
- [ ] **Step 4: Write `README.md`** in spec §5's 13-part order, using the task's **Hook**, **Story seed**, **Concept**, **At work**, **Investigate path**, **Root cause**, **Verify** and **Lifelong lesson** lines. Show real expected output snippets: copy them from an actual run, never invent them. Laptop and playground "open it" lines go in Break it and Verify.
- [ ] **Step 5: Run `./tests/scenarios/docker.sh NN`.** Expected: ✅ (two full cycles).
- [ ] **Step 6: Rehearse by hand once**, as the instructor would: run every command in the README in order and confirm each output matches what the README shows. Fix the README where it doesn't.
- [ ] **Step 7: Lint.** `shellcheck -S warning docker/scenarios/NN-*/cleanup.sh docker/scenarios/NN-*/*/*.sh tests/scenarios/docker/NN.sh`. Expected: no output.

---

### Task 2: D01 `01-jupyter-vanishes` (♻️ from `01-container-exits-immediately`)
- **App/ports:** Jupyter `d01-jupyter`, 8101→8888. ⬇️ ~343 MB, the first Jupyter scenario.
- **Break:** `docker run -d --name d01-jupyter … quay.io/jupyter/base-notebook:<tag> start-notebok.py --IdentityProvider.token=change-me-123` (typo: `notebok`). The container exits immediately.
- **Fix:** the same command with `start-notebook.py`.
- **Assert broken:** `container_state d01-jupyter` = `exited`; ExitCode = `127`; `docker logs d01-jupyter` contains `not found`.
- **Assert fixed:** `container_state d01-jupyter` = `running`; `http_code "http://localhost:8101/api/status?token=change-me-123"` = `200`.
- **Hook:** "You click run, Jupyter blinks… and it's gone."
- **Concept:** a container lives exactly as long as its main process (PID 1); exit codes 0 / 1 / 127 / 137.
- **At work:** a typo in a Kubernetes `command:`, a missing entrypoint after an image upgrade, CI jobs that "pass" in 0.1 s.
- **Investigate path:** `docker ps` (nothing!) → `docker ps -a` (Exited 127) → `docker logs d01-jupyter` → `docker inspect -f '{{.Config.Cmd}}' d01-jupyter`.
- **Root cause:** the command name is misspelled, so the shell can't find it (127), the process ends, and so the container ends.
- **Verify:** open `http://localhost:8101/lab?token=change-me-123` (playground: port 8101 URL + `/lab?token=change-me-123`), `docker ps`.
- **Lifelong lesson:** "When a container dies, don't stare at the container. Read its last words: `docker logs`."

### Task 3: D02 `02-port-clash` (♻️ from `02-port-already-allocated`)
- **Apps/ports:** Excalidraw `d02-draw` on 8102→80 (⬇️ 44 MB); IT-Tools `d02-tools` tries 8102→80 (⬇️ 24 MB). Fix moves IT-Tools to 8202.
- **Break:** start `d02-draw`; then `docker run -d --name d02-tools -p 8102:80 …`. That fails, and `break.sh` lets the real error print (it is the lesson), then continues.
- **Assert broken:** `container_state d02-draw` = `running`; `container_state d02-tools` = `created`; `http_code http://localhost:8202` ≠ `200`.
- **Assert fixed:** both containers `running`; `http_code http://localhost:8102` = `200` and `http_code http://localhost:8202` = `200`.
- **Hook:** "Two great apps. One door. Only one gets in."
- **Concept:** a host port can be published by exactly one container; the container port can repeat freely (`-p HOST:CONTAINER`).
- **At work:** two services both wanting 8080 on a VM, a forgotten dev server, local Postgres clashing with Docker Postgres on 5432.
- **Investigate path:** read the error → `docker ps -a` (IT-Tools stuck at Created) → `docker ps --filter publish=8102` → `docker port d02-draw`.
- **Root cause:** host port 8102 is already published by `d02-draw`.
- **Verify:** both URLs open; `docker ps --format '{{.Names}}  {{.Ports}}'`.
- **Lifelong lesson:** "Read the first error line slowly. It usually names the culprit."
- **Also:** complete `test_any_cwd` in `tests/scenarios/docker-selftest.sh` and run the self-test; expected all ✅.

### Task 4: D03 `03-votes-cant-reach-redis` (♻️ from `03-api-cannot-reach-redis`)
- **Apps/ports:** Cats vs Dogs API built from `apps/api` as image `d03-api:1.0` (label `z2h.scenario=d03`), `d03-redis` (`redis:7-alpine`), network `d03-net`; API 8103→8080.
- **Break:** the API runs with `-e REDIS_HOST=localhost`.
- **Fix:** `-e REDIS_HOST=d03-redis`.
- **Assert broken:** `curl -s localhost:8103/readyz` doesn't contain `ok` (match the app's real readyz body); `curl -s "localhost:8103/api/vote?option=cats"` reports an error.
- **Assert fixed:** `/readyz` is `200`; voting twice increments the count in `/api/results`.
- **Hook:** "The voting booth is open, but every vote vanishes into thin air."
- **Concept:** each container has its own network namespace; `localhost` means "me". Use service names on a user-defined network.
- **At work:** the #1 docker-compose bug; apps moved from a laptop (where everything was localhost) into containers.
- **Investigate path:** `curl …/readyz` → `docker logs d03-api` → `docker exec d03-api printenv REDIS_HOST` → `docker network inspect d03-net` (who's on it?) → `docker exec d03-api python -c "import socket;print(socket.gethostbyname('d03-redis'))"`.
- **Root cause:** the API looks for Redis at `localhost`, which is the API's own container.
- **Verify:** vote in the browser at `:8103`, watch the counts persist, `curl …/api/results`.
- **Lifelong lesson:** "`localhost` is a perspective, not a place."

### Task 5: D04 `04-vscode-wrong-password` (♻️ from `04-missing-env-var`)
- **App/port:** VS Code `d04-vscode` (`codercom/code-server:<tag>`), 8104→8080. ⬇️ ~380 MB.
- **Story seed:** the team lead says "the password is `change-me-123`", but whoever started the container forgot to set it.
- **Break:** `docker run -d --name d04-vscode -p 8104:8080 codercom/code-server:<tag>` (no `PASSWORD`).
- **Fix:** add `-e PASSWORD=change-me-123`.
- **Assert broken:** `curl -s -o /dev/null -w '%{http_code}' --data-urlencode password=change-me-123 localhost:8104/login` ≠ `302`; `docker exec d04-vscode printenv PASSWORD` fails.
- **Assert fixed:** the same POST returns `302`.
- **Hook:** "You type the right password. VS Code says it's wrong. Who's lying?"
- **Concept:** configuration comes from the environment (`-e`); without it the app falls back to defaults (here: a random password in `~/.config/code-server/config.yaml`).
- **At work:** a missing `DATABASE_URL` in production, `.env` files that never reached the server, Kubernetes Secrets not mounted.
- **Investigate path:** log in (fails) → `docker logs d04-vscode` (the "Using password from …config.yaml" line) → `docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' d04-vscode` → `docker exec d04-vscode cat /home/coder/.config/code-server/config.yaml`.
- **Root cause:** `PASSWORD` was never passed, so code-server generated its own.
- **Verify:** log in with `change-me-123`; `docker exec d04-vscode printenv PASSWORD`.
- **Lifelong lesson:** "If it's not in `docker inspect`, the app never got it."

### Task 6: D05 `05-image-tag-typo` (♻️ from `05-image-not-found`)
- **App/port:** Excalidraw `d05-draw`, 8105→80.
- **Break:** `docker run -d --name d05-draw -p 8105:80 excalidraw/excalidraw:lastest` (typo in the tag). `break.sh` prints the real error and the exit code.
- **Fix:** the correct pinned tag.
- **Assert broken:** no container named `d05-draw` exists (`docker ps -aq --filter name=^d05-draw$` is empty).
- **Assert fixed:** `container_state d05-draw` = `running`; `http_code http://localhost:8105` = `200`.
- **Hook:** "One letter. That's all it takes to break a deploy."
- **Concept:** image reference = registry/repo:tag; a tag is a label that must exist in the registry; `latest` is not magic.
- **At work:** failed deploys from mistyped tags, deleted tags, private-registry auth (same error family).
- **Investigate path:** read `manifest unknown` / `not found` → `docker ps -a` (nothing was created) → `docker manifest inspect excalidraw/excalidraw:lastest` vs the pinned tag → check the tags list on Docker Hub.
- **Root cause:** the tag `lastest` doesn't exist.
- **Verify:** the app opens; `docker image ls excalidraw/excalidraw`.
- **Lifelong lesson:** "Copy-paste versions. Never type them from memory."

### Task 7: D06 `06-jupyter-oom-killed` (♻️ from `06-oom-killed`)
- **App:** Jupyter image (cached from D01) running a "model training" Python one-liner as the container command: it allocates **600 MB** in steps, printing progress (`epoch 1/5 … loading 120 MB`). Container `d06-trainer`, `--memory 300m --memory-swap 300m`, no restart policy. No port.
- **Fix:** `--memory 1g`, then the script finishes and prints `✅ model trained`.
- **Calibration:** measure the image's Python baseline once and keep allocation − limit ≥ 200 MB, so it is OOM-killed on every platform. Record the numbers in the README.
- **Assert broken:** `docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer` = `true 137`.
- **Assert fixed:** ExitCode `0`; logs contain `model trained`.
- **Hook:** "Your AI model was 80% trained. Then it vanished. No error. No goodbye."
- **Concept:** memory limits are cgroups (D00 §7.2); exceeding one makes the kernel's OOM killer send SIGKILL; 137 = 128 + 9.
- **At work:** Kubernetes `OOMKilled` (scenario K-08), Java heap vs container limit, data jobs on big files.
- **Investigate path:** `docker ps -a` (Exited 137) → `docker logs` (stops mid-epoch) → `docker inspect … OOMKilled` → `docker inspect -f '{{.HostConfig.Memory}}'`.
- **Root cause:** the workload needs ~600 MB; the limit is 300 MB.
- **Verify:** `docker logs d06-trainer`; `docker stats --no-stream` during a rerun.
- **Lifelong lesson:** "Exit 137 means someone killed it. Find out who, and why."

### Task 8: D07 `07-jupyter-cant-save` (♻️ from `07-volume-permission-denied`)
- **App/port:** Jupyter `d07-jupyter`, 8107→8888, token `change-me-123`; named volume `d07-notebooks` mounted at `/home/jovyan/work`.
- **Break:** before Jupyter starts, a one-off `busybox:1.36` container creates `/data/assignments` owned by `root:root`, mode `755` (an "old backup job").
- **Fix:** one-off `docker run --rm -v d07-notebooks:/data busybox:1.36 chown -R 1000:100 /data`, then restart `d07-jupyter`.
- **Assert broken:** `docker exec d07-jupyter touch /home/jovyan/work/assignments/test.ipynb` fails with `Permission denied`.
- **Assert fixed:** the same command succeeds.
- **Hook:** "Two hours of notebook work. You press Save. 'Permission denied.'"
- **Concept:** containers run as a user (Jupyter: uid 1000 `jovyan`); files in volumes have owners; root-created folders lock others out.
- **At work:** volumes shared between jobs run as different users, NFS mounts, Kubernetes `fsGroup`.
- **Investigate path:** Save fails in the UI → `docker exec d07-jupyter id` → `docker exec d07-jupyter ls -ln /home/jovyan/work` → `docker volume inspect d07-notebooks`.
- **Root cause:** the folder is owned by root (uid 0); Jupyter runs as uid 1000.
- **Verify:** save a notebook in the UI; `ls -ln` shows `1000 100`.
- **Lifelong lesson:** "Every file has an owner and every process has a user. Make them agree."
- Uses a named volume, not a bind mount (spec §10.5).

### Task 9: D08 `08-it-tools-unhealthy` (♻️ from `08-unhealthy-container`)
- **App/port:** IT-Tools `d08-tools`, 8108→80.
- **Break:** `--health-cmd 'wget -qO- http://127.0.0.1:8080/ || exit 1' --health-interval 3s --health-retries 2`. The wrong port: the app listens on 80.
- **Fix:** the health check uses port `80`.
- **Pre-check during build:** confirm `wget` exists in the image (`docker run --rm --entrypoint sh corentinth/it-tools:<tag> -c 'command -v wget'`). If not, use `curl` or `nc`, whichever exists.
- **Assert broken:** `{{.State.Health.Status}}` = `unhealthy` **and** `http_code http://localhost:8108` = `200`.
- **Assert fixed:** `{{.State.Health.Status}}` = `healthy`.
- **Hook:** "The app works perfectly. Docker swears it's sick."
- **Concept:** a health check is a command Docker runs inside the container; `unhealthy` is a verdict about the check, not proof about the app.
- **At work:** load balancers pulling healthy servers, Compose `service_healthy`, Kubernetes probes (K-06, K-07).
- **Investigate path:** `docker ps` (unhealthy) → open the app (it works!) → `docker inspect -f '{{json .State.Health}}' d08-tools` (read the `Output`) → `docker inspect -f '{{json .Config.Healthcheck}}'`.
- **Root cause:** the check probes port 8080; the app is on 80.
- **Verify:** `docker ps` shows `(healthy)`.
- **Lifelong lesson:** "Test your tests. A wrong health check is worse than none."

### Task 10: D09 `09-status-board-no-dns` (♻️ from `09-default-bridge-dns`)
- **Apps/ports:** Excalidraw `d09-draw`, IT-Tools `d09-tools` (no published ports), and a "Campus status board" `d09-board`: `python:3.12-alpine` running a ~30-line stdlib script, mounted read-only from `break/board.py` (identical copy in `fix/`). Every 3 s it checks `http://d09-draw` and `http://d09-tools`, prints `✅ d09-draw up` / `❌ d09-draw: <reason>`, and serves a tiny auto-refreshing HTML status page on 8109→8000.
- **Break:** all three run on the **default bridge**.
- **Fix:** create network `d09-net`, connect all three (`docker network connect`), no restarts needed.
- **Assert broken:** `docker logs --tail 5 d09-board` contains `❌ d09-draw`.
- **Assert fixed:** after ≤10 s, `docker logs --tail 2 d09-board` contains `✅ d09-draw up` and `✅ d09-tools up`.
- **Hook:** "The status board says everything is down. Everything is up."
- **Concept:** user-defined networks give containers a built-in DNS (the "phone book"); the default bridge has none.
- **At work:** legacy `--link` setups, scripts using `docker run` without `--network`, Compose (which always creates a network for you).
- **Investigate path:** open the board at `:8109` → `docker logs d09-board` → `docker exec d09-board python -c "import socket;socket.gethostbyname('d09-draw')"` (fails) → `docker inspect -f '{{json .NetworkSettings.Networks}}' d09-board` (`bridge`) → `docker network ls`.
- **Root cause:** the default bridge has no DNS for container names.
- **Verify:** the board turns all ✅; `docker network inspect d09-net`.
- **Lifelong lesson:** "Things can't talk until they share a network, and know each other's names."

### Task 11: D10 `10-qr-app-build-fails` (♻️ from `10-build-fails-dockerignore`)
- **App/port:** a "Make your own QR code" web page: `nginx:1.27-alpine` + `index.html` + vendored `qrcode.min.js`. Use an MIT-licensed QR generator library (e.g. Kazuhiko Arase's `qrcode-generator`) with its license file. Image `d10-qr:1.0`, container `d10-qr`, 8110→80. The page has a text box ("your GitHub / LinkedIn URL") and draws the QR code client-side, with no network calls.
- **Break:** `break/` holds the app with a `.dockerignore` containing `*.js` ("someone excluded test files"). `break.sh` runs `docker build` (it fails), then `docker run` (it fails: no image).
- **Fix:** `fix/.dockerignore` excludes only `*.test.js` and `node_modules/`; build, then run.
- **Assert broken:** the `docker build` exit code is non-zero; image `d10-qr:1.0` doesn't exist.
- **Assert fixed:** `http_code http://localhost:8110` = `200`; `curl -s localhost:8110/qrcode.min.js | head -c 200` is non-empty.
- **Hook:** "The file is RIGHT THERE. Docker says it doesn't exist."
- **Concept:** the build context: Docker only sees files sent to the builder, and `.dockerignore` filters them first.
- **At work:** CI builds failing after someone "cleans up" `.dockerignore`; giant contexts (`node_modules`) slowing builds.
- **Investigate path:** read `"/qrcode.min.js": not found` → `ls break/` (it's there!) → `cat break/.dockerignore` → `docker build --progress=plain` (the context size line).
- **Root cause:** `*.js` in `.dockerignore` removes the library from the build context.
- **Verify:** open `:8110`, type your profile URL, scan the QR code with your phone.
- **Lifelong lesson:** "What Docker sees is not what you see. Check the context."

### Task 12: D11 `11-portfolio-localhost-only` (🆕)
- **App/port:** "Priya's portfolio" (a tiny, nice static HTML page) served by `python:3.12-alpine`'s `python -m http.server`. Image `d11-portfolio:1.0` built from `break/Dockerfile` with `CMD ["python","-m","http.server","8000","--bind","127.0.0.1"]`; 8111→8000.
- **Fix:** `fix/Dockerfile` binds `0.0.0.0`; rebuild and rerun.
- **Assert broken:** `container_state d11-portfolio` = `running`; `http_code http://localhost:8111` ≠ `200`; `docker exec d11-portfolio wget -qO- http://127.0.0.1:8000` succeeds.
- **Assert fixed:** `http_code http://localhost:8111` = `200`.
- **Hook:** "It works inside. It's running. And nobody can see it."
- **Concept:** a published port forwards traffic to the container's network interface; an app listening on 127.0.0.1 only accepts connections from inside its own container.
- **At work:** Flask/Vite/Rails dev servers default to 127.0.0.1; the same bug in Kubernetes Pods.
- **Investigate path:** `curl localhost:8111` (connection reset / empty reply) → `docker ps` (running, port published) → `docker exec … wget 127.0.0.1:8000` (works inside!) → `docker logs` ("Serving HTTP on 127.0.0.1") → `docker exec d11-portfolio netstat -tln` (if available, else `cat /proc/net/tcp`).
- **Root cause:** the server binds 127.0.0.1 inside the container.
- **Verify:** open `:8111`.
- **Lifelong lesson:** "Inside a container, listen on 0.0.0.0. 127.0.0.1 is a wall."
- Link back to D01 §4's `127.0.0.1` lesson (same idea, from the outside).

### Task 13: D12 `12-high-score-lost-on-stop` (🆕)
- **App/port:** "Dosa Dash", an **original** tiny HTML5 game (catch falling dosas, ~150 lines, no external assets), served with a high-score API by a stdlib Python server `server.py`. Scores are kept in memory and **saved to `/data/scores.json` only on SIGTERM** (`signal.signal(SIGTERM, save_and_exit)`). Image `d12-game:1.0`, volume `d12-data`, 8112→8000. `break.sh` posts 3 demo scores via `curl`.
- **Break:** `break/Dockerfile` uses a **shell-form** CMD that keeps `sh` as PID 1, e.g. `CMD python server.py | tee /data/server.log` (the pipe guarantees `sh` stays PID 1 on every shell). `break.sh` posts scores, then runs `time docker stop -t 10 d12-game`.
- **Fix:** exec form `CMD ["python","server.py"]`, with logging moved into Python.
- **Assert broken:** the `docker stop -t 10` duration ≥ 9 s (measure with `date +%s`); ExitCode `137`; `scores.json` in the volume lacks the demo scores (read via `docker run --rm -v d12-data:/data busybox:1.36 cat /data/scores.json`).
- **Assert fixed:** stop takes ≤ 3 s; ExitCode `0`; `scores.json` contains the 3 demo names.
- **Hook:** "You beat the high score. The server restarts. Your name is gone."
- **Concept:** `docker stop` sends SIGTERM to PID 1, waits, then SIGKILLs; shell form makes `sh` PID 1, and it doesn't pass signals on; exec form makes your app PID 1.
- **At work:** slow rolling deploys (every Pod waits 30 s), lost in-flight requests, DB connections not closed; `--init` / `tini`.
- **Investigate path:** time the stop → `docker inspect -f '{{.State.ExitCode}}'` (137) → `docker top d12-game` / `docker exec d12-game ps` (PID 1 is `sh`) → `docker inspect -f '{{json .Config.Cmd}}'` (`/bin/sh -c …`).
- **Root cause:** the shell is PID 1, swallows SIGTERM, so the save never happens.
- **Verify:** play, post a score, `docker stop` (fast), start again; the high score is still there.
- **Lifelong lesson:** "Graceful shutdown is a feature. Design for the goodbye."

### Task 14: D13 `13-portfolio-disappears` (🆕)
- **App/port:** "Priya's portfolio" again (reuse D11's HTML), baked into `d13-site:1.0` (`nginx:1.27-alpine`, `COPY site/ /usr/share/nginx/html/`), 8113→80.
- **Break:** run with a bind mount of `break/dev-notes/` (a folder containing only `TODO.txt`) onto `/usr/share/nginx/html` ("a teammate wanted live edits"). Make the path absolute from the script location. On Windows/WSL the repo lives in the Linux filesystem: note this in the README.
- **Fix:** run without the mount.
- **Assert broken:** `http_code http://localhost:8113` = `403` or `404`; `docker exec d13-site ls /usr/share/nginx/html` shows only `TODO.txt`.
- **Assert fixed:** `http_code` = `200`; the page contains the portfolio title.
- **Hook:** "The website is in the image. You can prove it. And it's gone."
- **Concept:** a bind mount **covers** what's at that path in the image (it doesn't merge); named volumes differ (copied on first use).
- **At work:** config mounts hiding defaults, `node_modules` hidden by a source mount, Kubernetes ConfigMap mounts replacing a whole directory.
- **Investigate path:** `curl -I localhost:8113` (403) → `docker exec … ls /usr/share/nginx/html` → `docker inspect -f '{{json .Mounts}}'` → `docker run --rm d13-site:1.0 ls /usr/share/nginx/html` (the files ARE in the image).
- **Root cause:** the mount covers the image's folder.
- **Verify:** open `:8113`.
- **Lifelong lesson:** "A mount doesn't add, it replaces. Know what you're covering."

### Task 15: D14 `14-leaked-api-key` (🆕)
- **App:** "Bengaluru weather widget", a tiny Python app that prints a fake forecast and "authenticates" with `WEATHER_API_KEY`. The key is an obviously fake demo value, `z2h-demo-key-NOT-REAL-123`, and the README says so. Image `d14-weather:broken`, then `d14-weather:fixed`. No port.
- **Break:** `break/Dockerfile` uses `ARG WEATHER_API_KEY` and `RUN echo "key=$WEATHER_API_KEY" > /app/config` ("a quick hack before the demo"). Built with `--build-arg WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123`. `break.sh` then "shares" the image (tags it `d14-weather:shared`).
- **Fix:** `fix/Dockerfile` uses `RUN --mount=type=secret,id=weather_key …`, built with `--secret id=weather_key,env=WEATHER_API_KEY` (BuildKit). The app reads the secret at runtime from `-e` in the demo run. Add a `# syntax=docker/dockerfile:1` header.
- **Assert broken:** `docker history --no-trunc d14-weather:broken | grep -c z2h-demo-key` ≥ `1`.
- **Assert fixed:** `docker history --no-trunc d14-weather:fixed | grep -c z2h-demo-key` = `0`, and `docker run --rm -e WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123 d14-weather:fixed` prints the forecast.
- **Hook:** "You never pushed the key to GitHub. You pushed it inside the image."
- **Concept:** every build step is saved as a layer with its metadata, readable by anyone who can pull the image.
- **At work:** leaked AWS keys in public images, scanners (`docker scout`, Trivy, GitGuardian), key rotation drills.
- **Investigate path:** `docker history d14-weather:broken` → `--no-trunc` → `docker inspect` (ENV/ARG) → "anyone with the image can do this".
- **Root cause:** a build ARG used in a RUN step is recorded in the image history.
- **Verify:** `docker history --no-trunc d14-weather:fixed | grep z2h-demo-key` prints nothing.
- **Lifelong lesson:** "If it's in the image, it's public. Secrets travel separately."
- `cleanup.sh` also removes all `d14-weather:*` tags (they carry the label).

### Task 16: D15 `15-compose-start-order` (🆕)
- **Apps/port:** Compose project `d15`:
  - `db`: `postgres:16-alpine` with `POSTGRES_PASSWORD=change-me-123` and no persistent volume (forces a fresh init every run).
  - `app`: "Dosa ratings board", `python:3.12-alpine` running a stdlib `app.py` mounted read-only. At start it opens **one** TCP connection to `db:5432`. On failure it prints `❌ database not reachable` and exits 1. On success it serves a ratings page on 8115→8000 that shows "✅ connected to the database".
- **Break:** `break/compose.yaml` has `depends_on: [db]` (start order only), `restart: "no"`.
- **Fix:** `fix/compose.yaml` adds the `db` healthcheck `pg_isready -U postgres` (interval 2s, retries 15) and `depends_on: db: condition: service_healthy`.
- **Pre-check during build:** confirm, ten times in a row, that Postgres's first-run init keeps TCP closed for ≥ 1 s (it uses a socket-only temporary server). If not reliable, the app connects at t=0 with no retry; the test must pass 10/10.
- **Assert broken:** `docker compose -p d15 ps -a app --format '{{.State}} {{.ExitCode}}'` = `exited 1`.
- **Assert fixed:** the app is `running`; `http_code http://localhost:8115` = `200`.
- **Hook:** "Everything starts. Nothing works. Run it again… and it works?!"
- **Concept:** `depends_on` controls start **order**, not **readiness**; health checks + `condition: service_healthy` wait for "ready".
- **At work:** flaky CI with databases, morning server reboots, Kubernetes init containers and readiness (K-26).
- **Investigate path:** `docker compose -p d15 ps -a` → `docker compose -p d15 logs app` → `docker compose -p d15 logs db` ("database system is ready" comes after the app died) → compare timestamps.
- **Root cause:** the app connected while Postgres was still initialising.
- **Verify:** open `:8115`; `docker compose -p d15 ps` (db healthy).
- **Lifelong lesson:** "Started is not ready. Wait for ready."
- `break.sh`/`fix.sh` use `docker compose -p d15 -f <abs path>/compose.yaml up -d`; `cleanup.sh` runs `docker compose -p d15 down -v --remove-orphans` (via `scenario_cleanup`).

---

### Task 17: Track integration and migration

**Files:**
- Create: `docker/scenarios/README.md`, `docker/scenarios/IMAGES.md`, `docker/scenarios/preload.sh`
- Modify: `labs.sh` (Docker parts only), `scripts/check-prereqs.sh` (IMAGES list), `README.md`, `SHOWTIME.md`, `docker/README.md`, `docker/00-foundations/README.md`, `docker/03-inside-containers/README.md`, `docker/11-limits-security/README.md`, any `kubernetes/**` README that links to `docker/troubleshooting`
- Delete: whatever remains of `docker/troubleshooting/` (`_lib.sh`, `README.md`) after the `git mv`s

- [ ] **Step 1: Write the test**: a link-and-reference check. `grep -rn "docker/troubleshooting" --exclude-dir=.git --exclude-dir=docs .` must print nothing, plus the repo's Markdown link checker (`problems: 0`).
- [ ] **Step 2: Run it.** Expected: matches in the files above.
- [ ] **Step 3: Write `docker/scenarios/README.md`**:
  - the lineup table (#, scenario, app, hook, ⬇️ size)
  - the class flow (spec §4)
  - platform notes: Windows = WSL2/Git Bash; Play with Docker supported
  - the **panic card**: run `./cleanup.sh`, check `docker ps --format '{{.Names}} {{.Ports}}'`, re-run `break.sh`
  - the **instructor preload checklist**: `./docker/scenarios/preload.sh` the day before, then run every scenario once
  - the **playground dry-run checklist**: Killercoda, iximiuz and Play with Docker; one line per scenario to tick
- [ ] **Step 4: Write `IMAGES.md`** (pinned tags, sizes, scenarios) and `preload.sh` (reads the image list from `IMAGES.md`'s table, or from an array kept in sync with it, pulls each, prints ✅/❌ and the total).
- [ ] **Step 5: Update `labs.sh`.**
  - `DOCKER_DIR` → `docker/scenarios`.
  - `title_of` reads the README's first line.
  - `list` shows Docker scenarios from the new folder.
  - `docker clean` runs every `docker/scenarios/*/cleanup.sh`.
  - Remove the `docker NN [fix]` paths and the Docker entries in `menu`, which prints "Docker scenarios: open docker/scenarios/README.md".
  - The Git and k8s behaviour is unchanged.
- [ ] **Step 6: Update `scripts/check-prereqs.sh` `IMAGES`**: add every image from `IMAGES.md` that isn't listed yet. Keep the existing entries: the labs still use them.
- [ ] **Step 7: Update every reference** found in Step 2 to the new paths and numbers (e.g. "scenario D-06" → `docker/scenarios/06-jupyter-oom-killed`). In SHOWTIME's Gauntlet, point Docker items at the new scenarios.
- [ ] **Step 8: Run the checks**:
  - Step 1's checks: no output and `problems: 0`
  - `bash tests/scenarios/docker-selftest.sh`: all ✅
  - `./tests/scenarios/docker.sh`: 15/15 ✅
  - `shellcheck -S warning labs.sh docker/scenarios/*.sh docker/scenarios/*/*.sh docker/scenarios/*/*/*.sh tests/scenarios/*.sh tests/scenarios/docker/*.sh`: no output
  - `./labs.sh list`
  - `./labs.sh docker clean`
- [ ] **Step 9: Leave the machine clean.** `./labs.sh docker clean`, then `docker ps -a --filter label=z2h.scenario --format '{{.Names}}'` prints nothing.
- [ ] **Step 10: Stop and ask the repo owner.** Report results (harness summary, any platform caveats found), then ask for "Commit & push". Do not commit before they answer.
