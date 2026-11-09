# D06 · No error, no goodbye

*Your AI model was a few epochs into training. Then it vanished. No error. No goodbye.*

⏱ 12 min · beginner · a small Python "AI trainer" (`python:3.12-alpine`) run with Docker Compose · compose files, resource fences, exit codes, reading `docker inspect`

⬇️ First run downloads about 19 MB (`python:3.12-alpine`, probably already on your laptop from other scenarios). Do it before the session anyway. The trainer image is built on your machine from a 5-line `Dockerfile`; there is no big Jupyter download in this one.

## 📖 The story
It's exam week at Christ University and your final-year project is a "model" that learns from a big dataset. You start the training in a container on the lab server (the kind of job you would normally run in a Jupyter notebook) and go for a filter coffee. When you come back, the output has stopped part-way through the epochs: no red error, no traceback, nothing. The container is just... gone. Your teammate says, *"Maybe Python crashed?"* Python did not crash. Someone else ended it.

## 🧠 The concept: why, what, how
**First, Compose in three sentences.** So far you typed long `docker run` lines with flags. A **`compose.yaml`** is a file that writes those flags down, so you read and edit them instead of retyping. `docker compose -f work/compose.yaml up -d` reads the file and does the `docker build` and `docker run` for you.

**Now the bug's world.** A container shares the host's memory and CPU with everyone else, so Docker lets you put fences around a container (`docker run --memory …`, or a line in the compose file). The kernel enforces those fences with a Linux feature called a **cgroup** (D00 §7.2). Fences are good. The question for today: what happens when a program meets one?

Think of a hostel mess with one plate per student: the rule is fine, until someone doesn't know about it.

## 🏢 Where you'll meet this at work
- **Kubernetes**: a Pod that restarts again and again with exit code 137 in `kubectl describe pod` (SRE, platform team; this is [scenario K08](../../../kubernetes/scenarios/08-ai-trainer-oomkilled/README.md)).
- **A service that runs fine on a laptop and dies in production**, with nothing in its logs (developer).
- **Data jobs on big files**: a nightly batch loads a file that grew this month (data engineer).

## 💥 Break it
`break/` holds three files: `trainer.py` (the "training"), `Dockerfile` (how to package it) and `compose.yaml` (how to run it). Run everything from this scenario folder. Make your own working copy and start it; `docker compose up -d --build` builds the image and starts the container in the background (`-f` says which compose file to use):
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
⏳ Waiting for the container to stop .... ✔ ready

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
NAME            IMAGE             COMMAND               SERVICE   CREATED         STATUS                                PORTS
d06-trainer-1   d06-trainer:1.0   "python trainer.py"   trainer   5 seconds ago   Exited (137) Less than a second ago   
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
trainer-1  | epoch 3/5 ... loading 150 MB
trainer-1  | epoch 4/5 ... loading 150 MB
```
It stops part-way, with no error message and no "model trained". A program that crashed on its own would usually say something. This one never got the chance. (It died at epoch 4 on the run above; on a machine where Docker may also use swap space it can be epoch 3 or 4. The story is the same.)

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
# One service: build the trainer from ./Dockerfile and run it.
name: d06

services:
  trainer:
    build: .
    image: d06-trainer:1.0
    mem_limit: 300m
    restart: "no"
```
One line is about memory: `mem_limit: 300m`.

**5. What will Docker really run? Compare with what we wrote.** `docker compose config` prints the file after Compose has read it, the "what Docker will really run" view:
```bash
docker compose -f work/compose.yaml config | grep -i mem
```
```
    mem_limit: "314572800"
```
314,572,800 bytes = 300 MiB. And the container itself agrees:
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

Calibration: a bare Python process on this image uses about 10 MB, so the kill is certain on any laptop: 750 MB needed against a 300 MB fence. On Docker Desktop the container may also borrow some swap space, so it can get one epoch further before the kill; it never gets to the end.
</details>

## 🔧 Fix it
What changed: the memory limit, nothing else. `fix/` holds the corrected copy:
```bash
diff break/compose.yaml fix/compose.yaml
```
```
8c8
<     mem_limit: 300m
---
>     mem_limit: 1g
```
By hand: open `work/compose.yaml` in your editor and change `300m` to `1g` (1 GB, comfortably above 750 MB). Then tell Compose to apply the file; it sees the container's settings changed and re-creates it (the image is unchanged, so there is nothing to rebuild):
```bash
docker compose -f work/compose.yaml up -d
```
```
 Container d06-trainer-1 Recreate 
 Container d06-trainer-1 Recreated 
 Container d06-trainer-1 Starting 
 Container d06-trainer-1 Started 
```
Or run `./fix/fix.sh`, which does the same from the corrected files (`./fix/fix.sh`; it makes a fresh `work/` and prints its commands).

## ✅ Verify it yourself
Right after `up -d`, watch the memory live (3 seconds in, mid-training):
```bash
sleep 3; docker stats --no-stream d06-trainer-1
```
```
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT   MEM %     NET I/O         BLOCK I/O     PIDS
472d3b40da3c   d06-trainer-1   3.30%     604.9MiB / 1GiB     59.08%    1.17kB / 126B   0B / 28.7kB   1
```
(Your numbers will differ a little.) Already past the old 300 MiB limit and happily running. The training takes about 5 seconds, so if you are slow the container will have finished and `docker stats` shows zeros: that is fine, read the proof instead:
```bash
docker compose -f work/compose.yaml ps -a
```
```
NAME            IMAGE             COMMAND               SERVICE   CREATED         STATUS                     PORTS
d06-trainer-1   d06-trainer:1.0   "python trainer.py"   trainer   9 seconds ago   Exited (0) 3 seconds ago   
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
Not killed, and a clean exit code **0**. (The outputs above come from one real run of the steps in this README, with pauses between commands; the second `up -d` printed no build output the second time because nothing was rebuilt.)

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
