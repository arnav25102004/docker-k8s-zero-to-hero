# D06 · No error, no goodbye

*Your AI model was a few epochs into training. Then it vanished. No error. No goodbye.*

⏱ 12 min · beginner · a small Python "AI trainer" (`python:3.12-alpine`) run with Docker Compose · compose files, exit codes, reading `docker inspect`

⬇️ First run downloads about 19 MB (`python:3.12-alpine`, probably already on your laptop from other scenarios). Do it before the session anyway. The trainer image is built on your machine from a short `Dockerfile`; there is no big Jupyter download in this one.

## 📖 The story
It's exam week at Christ University and your final-year project is a "model" that learns from a big dataset. You start the training in a container on the lab server (the kind of job you would normally run in a Jupyter notebook) and go for a filter coffee. When you come back, the output has stopped part-way through the epochs: no red error, no traceback, nothing. The container is just... gone. Your teammate says, *"Maybe Python crashed?"* Python did not crash. Someone else ended it.

## 🧠 The concept: why, what, how
**First, Compose in three sentences.** So far you typed long `docker run` lines with flags. A **`compose.yaml`** is a file that writes those flags down, so you read and edit them instead of retyping. `docker compose -f work/compose.yaml up -d` reads the file and does the `docker build` and `docker run` for you.

**Now the bug's world.** A container is just a process on a machine that many other things share. When one of them stops without saying why, you do not guess: you read what you wrote down (the files) and what Docker recorded (`docker inspect`, logs, exit codes), and compare the two.

## 🏢 Where you'll meet this at work
- **Kubernetes**: a Pod that restarts again and again with nothing useful in its logs (SRE, platform team; this is [scenario K08](../../../kubernetes/scenarios/08-ai-trainer-oomkilled/README.md)).
- **A service that runs fine on a laptop and dies in production**, with nothing in its logs (developer).
- **Data jobs on big files**: a nightly batch loads a file that grew this month (data engineer).

## 💥 Break it
`break/` holds three files: `trainer.py` (the "training"), `Dockerfile` (how to package it) and `compose.yaml` (how to run it). Run everything from this scenario folder. Make your own working copy and start it; `docker compose -f work/compose.yaml up -d --build` builds the image and starts the container in the background (`-f` says which compose file to use; `build: .` inside it is relative to the compose file's own folder, `work/`, not to the folder you type from):
```bash
rm -rf work && cp -R break work
docker compose -f work/compose.yaml up -d --build
```
Or the one-line shortcut, which does the same and prints every command it runs:
```bash
./break/break.sh
```
Real output of `./break/break.sh` (shortened: the build log and some repeated lines are left out):
```
✅ Scenario d06 cleaned up
▶ $ rm -rf work && cp -R break work
▶ $ docker compose -f work/compose.yaml up -d --build
 Image d06-trainer:1.0 Building 
 Image d06-trainer:1.0 Built 
 Network d06_default Created 
 Container d06-trainer-1 Created 
 Container d06-trainer-1 Started 
⏳ Waiting for the container to stop .. ✔ ready

👀 What you should see now
   Your AI model was training. Now the container is gone from 'docker ps': no error, no goodbye.

👉 Next
   docker compose -f work/compose.yaml ps -a
```
The "training" starts, prints a few epochs, and then, part-way through, the container stops. Nothing shows on screen. No port to open: this one is all in the terminal.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is it running? What state is it in?** (`-a` also lists containers that have stopped.)
```bash
docker compose -f work/compose.yaml ps -a
```
```
NAME            IMAGE             COMMAND               SERVICE   CREATED         STATUS                      PORTS
d06-trainer-1   d06-trainer:1.0   "python trainer.py"   trainer   3 seconds ago   Exited (137) 1 second ago   
```
Not running (plain `docker compose ps` would show nothing). Look at the status: `Exited (137)`. That number is a clue.

<details><summary>💡 Hint</summary>
137 is not a number the program chose. Exit codes above 128 mean "killed by signal (code - 128)". Which signal is 137 - 128? And who sends it, if the program didn't crash? Then look at the line in <code>work/compose.yaml</code> that talks about memory.
</details>

**2. What did the program say before it died?**
```bash
docker compose -f work/compose.yaml logs trainer
```
```
trainer-1  | epoch 1/5 ... loading 150 MB
trainer-1  | epoch 2/5 ... loading 150 MB
```
It stops after epoch 2 is announced, with no error message and no "model trained". A program that crashed on its own would usually say something. This one never got the chance. (It dies during epoch 2 on every engine: the compose file also limits swap, see below, so the epoch count is the same everywhere.)

**3. Ask Docker: was it killed for memory?**
```bash
docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer-1
```
```
true 137
```
`OOMKilled` is `true`. The kernel's OOM killer ended it, and the exit code 137 is 128 + 9 (SIGKILL).

**4. What did we write down for the container? Read the file.**
```bash
cat work/compose.yaml
```
```
# What to run, written down.
name: d06                     # the project name; containers are called d06-<service>-1

services:
  trainer:                    # one service, one container
    build: .                  # build the image from the Dockerfile next to this file
    image: d06-trainer:1.0    # name the built image
    mem_limit: 300m
    memswap_limit: 300m
    restart: "no"             # do not start it again when it stops
```
The comments say what the keys mean. Two lines are about memory: `mem_limit` and `memswap_limit` (swap is disk space used as slow extra memory).

**5. What will Docker really run? Compare with what we wrote.** `docker compose config` prints the file after Compose has read it, the "what Docker will really run" view:
```bash
docker compose -f work/compose.yaml config | grep -i mem
```
```
    mem_limit: "314572800"
    memswap_limit: "314572800"
```
Newer Compose versions print bytes like this; older ones may print `300m`. 314,572,800 bytes = 300 MiB. And the container itself agrees:
```bash
docker inspect -f '{{.HostConfig.Memory}}' d06-trainer-1
```
```
314572800
```
(Does the program need more than that? Each epoch loads 150 MB, five epochs: 750 MB. Open `work/trainer.py` and see.)

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

Docker's memory limit is a hard fence (a cgroup). Inside it the program keeps asking for memory and gets it, until the fence is full. Then the kernel's **OOM killer** (OOM = Out Of Memory) ends the process with `SIGKILL` (signal 9). A SIGKILL cannot be caught, so the program never gets to print an error. Docker records `OOMKilled=true`, and the exit code is **137 = 128 + 9**.

The training needs about **750 MB** (5 epochs x 150 MB); `compose.yaml` gives the container only **300 MB** (`mem_limit: 300m`). When the next epoch pushed memory past the fence, the kernel's OOM killer sent SIGKILL. Python never saw it coming, so there was no error in the logs. Docker recorded it as `OOMKilled=true`, exit code 137.

Calibration: a bare Python process on this image uses about 10 MB, so epoch 1 fits (about 160 MB) and epoch 2 (about 310 MB) does not fit in 300 MB: the kill comes during epoch 2, never at the end. `memswap_limit: 300m` (same as `mem_limit`) means the container cannot borrow swap space either; without it, Docker Desktop would let it spill into swap and die a few epochs later, and the epoch would differ between machines.
</details>

## 🔧 Fix it
What changed: the memory limit, nothing else. `fix/` holds the corrected copy:
```bash
diff break/compose.yaml fix/compose.yaml
```
```
8,9c8,9
<     mem_limit: 300m
<     memswap_limit: 300m
---
>     mem_limit: 1g
>     memswap_limit: 1g
```
By hand: open `work/compose.yaml` in your editor and change both `300m` lines to `1g` (1 GB, comfortably above 750 MB). Then run the same command `fix.sh` prints; Compose sees the container's settings changed and re-creates it (the image is unchanged, so the build step is instant):
```bash
docker compose -f work/compose.yaml up -d --build
```
```
 Image d06-trainer:1.0 Building 
 Image d06-trainer:1.0 Built 
 Container d06-trainer-1 Recreate 
 Container d06-trainer-1 Recreated 
 Container d06-trainer-1 Starting 
 Container d06-trainer-1 Started 
```
Or run `./fix/fix.sh`, which does the same from the corrected files (it makes a fresh `work/` and prints its commands).

## ✅ Verify it yourself
Right after `up -d --build`, watch the memory live (3 seconds in, mid-training):
```bash
sleep 3; docker stats --no-stream d06-trainer-1
```
```
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT   MEM %     NET I/O         BLOCK I/O     PIDS
8190b46f2aea   d06-trainer-1   3.85%     604.9MiB / 1GiB     59.08%    1.17kB / 126B   0B / 0B   1
```
(Your numbers will differ a little.) Already past the old 300 MiB limit and happily running. The training takes about 5 seconds, so if you are slow the container will have finished and `docker stats` shows zeros: that is fine, read the proof instead:
```bash
docker compose -f work/compose.yaml ps -a
```
```
NAME            IMAGE             COMMAND               SERVICE   CREATED          STATUS                     PORTS
d06-trainer-1   d06-trainer:1.0   "python trainer.py"   trainer   10 seconds ago   Exited (0) 3 seconds ago   
```
```bash
docker compose -f work/compose.yaml logs trainer
```
```
trainer-1  | epoch 1/5 ... loading 150 MB
trainer-1  | epoch 2/5 ... loading 150 MB
trainer-1  | epoch 3/5 ... loading 150 MB
trainer-1  | epoch 4/5 ... loading 150 MB
trainer-1  | epoch 5/5 ... loading 150 MB
trainer-1  | model trained
```
```bash
docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer-1
```
```
false 0
```
Not killed, and a clean exit code **0**. (The outputs above come from one real run of the steps in this README, with pauses between commands; the build lines in the fix output were instant because the image was cached.)

## 🎯 Key takeaways
- A `compose.yaml` is `docker run` flags written down; `docker compose config` shows what Compose will really use.
- `mem_limit` (like `--memory`) is a hard fence (a cgroup). Go over it and the kernel kills the process, with no warning to the program.
- Exit code **137 = 128 + 9 = SIGKILL**. `OOMKilled=true` in `docker inspect` is the proof it was memory.
- The logs of an OOM kill just *stop*. Absence of an error is itself the clue.
- Set limits from measured usage plus headroom (`docker stats`), and alert on OOM kills.

## 💎 Lifelong lesson
> Exit 137 means someone killed it. Find out who, and why.

## 🧹 Clean up
```bash
./cleanup.sh
```
(It removes the container, network and image `d06-*`, and deletes `work/`.)

## Next →
[D07](../07-jupyter-cant-save/README.md): Jupyter can't save your notebook: "permission denied". The container is running, but it isn't allowed to write.
