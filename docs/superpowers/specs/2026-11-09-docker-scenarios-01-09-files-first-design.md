# Docker scenarios D01–D09, files first: design

## Why

D01–D09 teach Docker without showing Docker. Every container is started inside `break.sh` / `fix.sh`, no scenario ships a Dockerfile or a compose file, and the README never shows the `docker run` line that holds the bug (D03's bug is `-e REDIS_HOST=localhost`, which nobody sees). The learner runs a script, watches something fail, runs another script. The owner's words: "the whole idea is to master docker, not randomly running some scripts which no one have any idea of."

## Goal

After D01–D09 a learner can, with no scripts: read and edit a Dockerfile, build it, run it with the right flags, read a small compose file, and find a bug by reading the files Docker was given and comparing them with what Docker actually ran.

## Principles (binding)

1. **The bug lives in a file or a command the learner can see.** Every scenario ships the learner-owned files in `break/`: a `Dockerfile` wherever the scenario builds or configures an image, a `compose.yaml` where the scenario runs several things together (from D06 on), or the exact `docker run` commands printed in the README. The fix is a change to one of those lines.
2. **Scripts stay, but only as a transparent shortcut.** The owner: "we can keep scripts in case of running multiple things like building docker images". `break.sh` / `fix.sh` still do the multi-step setup, but they print every Docker command before running it (`▶ docker build -t d01-jupyter:1.0 .`), exactly as typed, so nothing is hidden. The README's "Break it" shows the commands to type by hand first and `./break.sh` as the one-line shortcut.
3. **The learner edits real files without dirtying the repo.** `break.sh` copies `break/` into a git-ignored `work/` folder inside the scenario and runs everything from there. The learner fixes the bug by editing `work/...` and re-running the build/run commands from the README. `fix.sh` copies `fix/` into `work/` and runs the same commands: the safety net. `diff break/X fix/X` shows "what changed". `cleanup.sh` removes `work/` too.
4. **Investigation compares "what I wrote" with "what Docker ran".** Every scenario has at least one step that reads the file (`cat work/Dockerfile`, `cat work/compose.yaml`) and one that reads Docker's view (`docker inspect`, `docker compose config`, `docker logs`, `docker ps -a`).
5. Everything else from the existing design stays: story/13-part README template, hint before reveal (also in comments of files presenters show before the hint, and in printed commands — a printed command may show the buggy line, because that is the evidence, but no comment may name the cause), real contiguous outputs, ports `81NN`/`82NN`, `dNN-` names, `z2h.scenario=dNN` labels, pinned images, Git Bash `MSYS_NO_PATHCONV=1`, the test harness (`tests/scenarios/docker.sh NN` two cycles, `nothing_left`), original fictional content, names Lakshmi/Ravi/Priya/Meera/Arjun (never "Asha").

## Progression (controller's call)

- **D01–D05: Dockerfile + `docker build` + `docker run`.** The core CLI. No compose yet.
- **D06–D09: Dockerfile + `compose.yaml`.** The same ideas written down as a file, leading into D15 (already compose).
- D10–D15 already follow principle 1; they get only the `▶` command printing and `work/` folder if cheap, not a rewrite (out of scope unless trivial).

## Per scenario (the bug moves into a file)

| # | Learner files in `break/` | The bug (one line) | Fix | Teaches |
|---|---|---|---|---|
| D01 Jupyter vanishes | `Dockerfile` (`FROM` the pinned Jupyter image, a welcome notebook `COPY`, `CMD`) | `CMD ["start-notebok.py", …]` | spell it right, rebuild, run | CMD, build vs run, `ps -a`, `logs`, exit codes |
| D02 Port clash | the two `docker run` lines (printed and in README); no Dockerfile: both are third-party images used as-is, and the README says why | both publish `-p 8102:80` | `-p 8202:80` | `-p host:container`, `docker ps` ports |
| D03 Votes vanish | `Dockerfile` for the API (copied from `apps/api`, with `ENV REDIS_HOST=localhost` as a baked-in default) + the run lines | the default is never overridden at run time | `docker run … -e REDIS_HOST=d03-redis` | ENV defaults vs run-time config, user networks, container names as hostnames, `docker inspect` env |
| D04 Wrong password | `app.env` passed with `--env-file` | `PASSWROD=change-me-123` (typo in the key) | fix the key, recreate | `--env-file`, env needs a recreate, `docker exec env` |
| D05 One character | `Dockerfile` `FROM corentinth/it-tools:<typo>` | the tag | copy the real tag, rebuild | `FROM`, tags, build fails before anything runs, `docker manifest inspect` / registry |
| D06 Trainer OOM | `Dockerfile` (python trainer script `COPY`) + `compose.yaml` with `mem_limit: 300m` | the limit | `mem_limit: 1g` | limits, `OOMKilled`, exit 137, `docker stats`, `compose config` |
| D07 Can't save | `compose.yaml` with a `backup` job (root) and `jupyter` sharing volume `notebooks` | the job writes as root | the README fix chowns the volume via `docker compose run --rm`, and the fixed compose gives the job `user: "1000:100"` so it never happens again | volumes, uids, `user:`, `ls -ln` inside |
| D08 Healthy app, sick label | `Dockerfile` (`FROM` it-tools + `HEALTHCHECK` curl/wget) | probes port 8080 | port 80 | `HEALTHCHECK`, `inspect .State.Health` |
| D09 No DNS | `Dockerfile` for the status board + `compose.yaml` with three services each set to `network_mode: bridge` | default bridge has no DNS | delete the three `network_mode` lines: compose's own network resolves names | default bridge vs user network, `compose config`, `docker network inspect` |

Exact pinned images stay as today (IMAGES.md). Where the table needs a tool inside an image (e.g. D08 health probe), the builder verifies it exists in that pinned image.

## Constraints

- Each scenario must still pass `tests/scenarios/docker.sh NN` (two cycles) and leave `nothing_left` true, including the new `work/` folder and built images (`dNN-*` tags, labelled).
- Existing test specs change only where a name or behaviour changes; the observable broken/fixed states (ports, HTTP codes, container states) should stay the same where possible.
- Must work on macOS/Linux Docker Desktop and Engine, WSL2, Git Bash (with `MSYS_NO_PATHCONV=1`), Play with Docker, Killercoda, iximiuz. Compose v2 (`docker compose`) is assumed from D06 on; `scripts/check-prereqs.sh` already checks Docker; it must check `docker compose version` too.
- No new network downloads beyond today's images except the small bases already pinned.
- `.gitignore` gets `docker/scenarios/*/work/`.

## Non-goals

- Rewriting D10–D15 or the D00–D11 labs.
- Changing the stories, apps or hooks (they work); only how the bug is delivered and investigated changes, plus the README steps that depend on it.

## Left to the builders

Exact file contents, step wording, which `inspect` format strings to show, and how each script prints commands (a shared `_lib.sh` helper `run_shown` that prints `▶ <command>` then runs it is the expected shape).
