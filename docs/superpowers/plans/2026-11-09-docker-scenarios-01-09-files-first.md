# Docker scenarios D01–D09, files first: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Rebuild D01–D09 so each bug lives in a Dockerfile, a compose file or a visible `docker run` line that the learner reads and edits; scripts become transparent shortcuts.

**Architecture:** Shared helpers in `docker/scenarios/_lib.sh` (`run_shown`, `prepare_work`), a git-ignored `work/` copy per scenario, then one task per scenario, then integration.

**Tech Stack:** bash, Docker Engine 29 / Compose v2, the existing harness `tests/scenarios/docker.sh`.

**Spec:** `docs/superpowers/specs/2026-11-09-docker-scenarios-01-09-files-first-design.md`

## Global Constraints

- The spec's five principles are binding; its per-scenario table is the target for each task.
- Ports `81NN`/`82NN`, names `dNN-…`, label `z2h.scenario=dNN` on everything (images, containers, networks, volumes — in compose via `labels:` on services, networks and volumes, and `name: dNN` as the compose project name so containers are `dNN-<service>-1`).
- Every printed Docker command is exactly what runs (`run_shown`). No comment or printed text names the cause before the README hint; a printed command may contain the buggy flag (that is evidence).
- README outputs are real, from one contiguous monotonic run, never hand-edited; `grep -A/-B` snippets show exactly what is printed. 13-part template, hint before reveal, "why next" lead-ins, honest download sizes.
- `tests/scenarios/docker.sh NN` passes two cycles and `nothing_left dNN` holds, and `no_images dNN` holds. `cleanup.sh` removes `work/`.
- Original fictional content; never the name "Asha".

## Review Focus

1. A learner who edits `work/Dockerfile` and re-runs the README's build/run lines must get the fixed state without running `fix.sh` (test this by hand in every task).
2. Re-running `break.sh` after a by-hand fix must restore the broken files (fresh `work/`).
3. Windows Git Bash: `work/` paths and `-v` mounts must not be mangled (`MSYS_NO_PATHCONV=1` note stays).
4. Compose-based scenarios must be removed completely by `cleanup.sh` even if the learner changed the project in `work/` (cleanup must not depend on the edited file).
5. The by-hand path in the README and `fix.sh` must reach the same end state (same image tag, same container names).

---

### Task 1: Shared helpers and plumbing

**Files:** `docker/scenarios/_lib.sh`, `.gitignore`, `scripts/check-prereqs.sh`, `tests/scenarios/docker-selftest.sh`, `tests/scenarios/lib.sh` (only if `nothing_left` needs to check `work/`).

- [ ] Add `run_shown CMD...`: prints `▶ $ CMD...` (plain, copy-pasteable, with the original quoting) then runs it, returning its exit status. Output of the command itself is shown or hidden by the caller (`run_shown_quiet` variant that hides stdout but still prints the command).
- [ ] Add `prepare_work SRC_DIR`: removes and recreates `<scenario>/work/` from `SRC_DIR` (portable `cp -R`), prints `▶ fresh copy of break/ in work/`.
- [ ] `scenario_cleanup` also removes `<scenario>/work/` and runs `docker compose -p dNN down -v --remove-orphans` by project name (not by file), so an edited `work/compose.yaml` cannot block cleanup.
- [ ] `.gitignore`: `docker/scenarios/*/work/`.
- [ ] `check-prereqs.sh`: report `docker compose version` (fail with a clear message if missing).
- [ ] Selftest cases: `run_shown` prints and propagates exit codes; `prepare_work` replaces an edited copy; cleanup removes `work/` and a compose project whose file was deleted.
- [ ] Commit.

### Task 2: D01 Jupyter vanishes — Dockerfile with a CMD typo
Per spec row D01. Build `d01-jupyter:1.0` from `work/Dockerfile` (FROM the pinned Jupyter image, a small original welcome notebook COPY, `CMD` with the typo). Investigate: `docker ps -a`, exit code, `docker logs`, `docker inspect -f '{{json .Config.Cmd}}'`, then `cat work/Dockerfile`. By-hand fix: edit `work/Dockerfile`, `docker build`, `docker rm`, `docker run`. Keep port 8101 and the existing broken/fixed observable states; update `tests/scenarios/docker/01.sh` only as needed.

### Task 3: D02 Port clash — the two run lines
Per spec row D02. No Dockerfile (say why in the README in one sentence). `break.sh` prints both `docker run` lines; the second fails with the real "port is already allocated" error. The README's Break section shows both lines to type by hand. Fix: the second line with `-p 8202:80`.

### Task 4: D03 Votes vanish — ENV default baked into the Dockerfile
Per spec row D03. `work/Dockerfile` is a copy of `apps/api/Dockerfile` plus `ENV REDIS_HOST=localhost` (keep the app source where it is; the Dockerfile's build context is passed explicitly, or the app files are copied into `work/` — builder's choice, explained). Run lines visible, including `docker network create d03-net`. Investigate with `docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}'` and `grep ENV work/Dockerfile`. Fix: `-e REDIS_HOST=d03-redis` at run time (README explains why run-time config beats a baked-in default).

### Task 5: D04 Wrong password — a typo in the env file
Per spec row D04. `work/app.env` with `PASSWROD=change-me-123`, run with `--env-file work/app.env`. Investigate: login fails, `docker logs` (code-server prints a generated password when PASSWORD is missing), `docker exec … env | grep -i pass`, `cat work/app.env`. Fix: correct the key, recreate (env changes need a new container).

### Task 6: D05 One character — the FROM tag
Per spec row D05. `work/Dockerfile` `FROM corentinth/it-tools:<swapped>`; `docker build` fails at FROM with the real "not found" error; nothing runs. Investigate the error line, the Docker Hub tag list or `docker manifest inspect`. Fix: the correct tag (copy-paste), rebuild, run on 8105.

### Task 7: D06 Trainer OOM — compose `mem_limit`
Per spec row D06. First compose scenario: the README introduces compose in three sentences (a file that writes down the `docker run` flags). `work/Dockerfile` (python trainer COPY) + `work/compose.yaml` (`name: d06`, `mem_limit: 300m`). Investigate `docker compose ps -a`, `docker inspect … .State.OOMKilled`, exit 137, `docker compose config | grep -i mem`. Fix: `mem_limit: 1g`, `docker compose up -d`.

### Task 8: D07 Can't save — volume owned by root
Per spec row D07. `work/compose.yaml` with `backup` (root, writes into the shared volume, then exits) and `jupyter` (uid 1000). Save fails. Investigate `docker compose exec jupyter ls -ln work`, `id`. Fix by hand: `docker compose run --rm --user root backup chown -R 1000:100 /data` (or equivalent), and the fixed compose gives `backup` `user: "1000:100"` so a re-run stays fixed. The test asserts saving works.

### Task 9: D08 Healthy app, sick label — HEALTHCHECK port
Per spec row D08. `work/Dockerfile` FROM pinned it-tools + `HEALTHCHECK` probing 8080 (verify which probe tool exists in that image). Investigate `docker ps` (unhealthy), `docker inspect -f '{{json .State.Health}}'`, `cat work/Dockerfile`. Fix: port 80, rebuild, run.

### Task 10: D09 No DNS — `network_mode: bridge`
Per spec row D09. `work/Dockerfile` for the status board (copies `board.py`) + `work/compose.yaml` with three services each `network_mode: bridge`. Investigate: the board's red rows, `docker compose exec board getent hosts draw` (or the tool available), `docker network inspect bridge`, `docker compose config`. Fix: delete the three lines, `docker compose up -d` (containers are recreated onto `d09_default`). README explains default bridge vs user networks.

### Task 11: Integration
- [ ] `docker/scenarios/README.md`: "How a session runs" says scripts are shortcuts that print every command, and the by-hand path edits `work/`; lineup unchanged unless a hook changed.
- [ ] `IMAGES.md`/`preload.sh`: any new built-image names or bases.
- [ ] `./tests/scenarios/docker.sh 01 02 03 04 05 06 07 08 09` all ✅ (two cycles each), then `10 11 12 13 14 15` as a regression; `docker-selftest.sh` ✅; shellcheck clean; link check 0 problems.
- [ ] Report; do not push.
