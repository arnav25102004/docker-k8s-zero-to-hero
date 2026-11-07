# D06 · No error, no goodbye

*Your AI model was more than halfway trained. Then it vanished. No error. No goodbye.*

⏱ 12 min · beginner · Jupyter image (`quay.io/jupyter/base-notebook:2026-11-02`) · memory limits, cgroups, exit code 137, OOMKilled

⬇️ First run downloads about 343 MB (the same image as D01, so it may already be on your laptop). Do it before the session anyway.

## 📖 The story
It's exam week at Christ University and your final-year project is a "model" that learns from a big dataset. You start the training in a container on the lab server and go for a filter coffee. When you come back, the output stops halfway: no red error, no traceback, nothing. The container is just... gone. Your teammate says, *"Maybe Python crashed?"* Python did not crash. Someone else ended it.

## 🧠 The concept: why, what, how
A container shares the host's memory with everyone else. To stop one greedy container from eating the whole machine, Docker can set a **memory limit** (`--memory 300m`). It is built on a Linux feature called a **cgroup** (D00 §7.2): a fence the kernel builds around a group of processes.

Think of a hostel mess with one plate per student. Take more than one plate and the warden quietly takes your tray away. He doesn't write you a letter.

- Inside the fence the program keeps asking for memory, and it gets it, until the fence is full.
- Then the kernel's **OOM killer** (OOM = Out Of Memory) ends the process with `SIGKILL` (signal 9). A SIGKILL cannot be caught, so the program never gets to print an error.
- Docker records it: `OOMKilled=true`, and the exit code is **137 = 128 + 9**.

## 🏢 Where you'll meet this at work
- **Kubernetes `OOMKilled`** in `kubectl describe pod`: same cause, same exit code 137 (SRE, platform team; this is scenario K-08).
- **A Java service whose heap is bigger than the container limit**: it runs fine on a laptop and dies in production (developer).
- **Data jobs on big files**: a nightly batch loads a file that grew this month (data engineer).

## 💥 Break it
```bash
cd break && ./break.sh
```
The "training" starts, prints a few epochs, and then the container stops, more than halfway through. Nothing shows on screen. No port to open: this one is all in the terminal.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is it running? What state is it in?**
```bash
docker ps -a --filter name=d06
```
```
CONTAINER ID   IMAGE                                      COMMAND                  CREATED         STATUS                                PORTS     NAMES
97177ec99136   quay.io/jupyter/base-notebook:2026-11-02   "python -c 'import t…"   2 seconds ago   Exited (137) Less than a second ago             d06-trainer
```
Not running (plain `docker ps` would show nothing). Look at the status: `Exited (137)`. That number is a clue.

<details><summary>💡 Hint</summary>
137 is not a number the program chose. Exit codes above 128 mean "killed by signal (code - 128)". Which signal is 137 - 128? And who sends it, if the program didn't crash?
</details>

**2. What did the program say before it died?**
```bash
docker logs d06-trainer
```
```
epoch 1/5 ... loading 120 MB
epoch 2/5 ... loading 120 MB
epoch 3/5 ... loading 120 MB
```
It stops in the middle of epoch 3, with no error message. A program that crashed on its own would usually say something. This one never got the chance.

**3. Ask Docker: was it killed for memory?**
```bash
docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer
```
```
true 137
```
`OOMKilled` is `true`. The kernel's OOM killer ended it, and the exit code 137 is 128 + 9 (SIGKILL).

**4. What limit did we give it?**
```bash
docker inspect -f '{{.HostConfig.Memory}}' d06-trainer
```
```
314572800
```
That's 314,572,800 bytes = **300 MiB**. (Does the program need more than that? Each epoch loads 120 MB, five epochs: 600 MB.)

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The training needs about **600 MB** (5 epochs x 120 MB); the container's memory limit is **300 MB**. When the third epoch pushed memory past the fence, the kernel's OOM killer sent SIGKILL. Python never saw it coming, so there was no error in the logs. Docker recorded it as `OOMKilled=true`, exit code 137.

Calibration, measured on this image (Python 3.13): a bare Python process uses about 9 MB. Allocation (600 MB) minus limit (300 MB) = 300 MB of overshoot, so the kill is certain on any laptop. It died at epoch 3 in every one of 6 consecutive runs.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: the memory limit, nothing else. `break.sh` first, `fix.sh` second:
```bash
grep -h -e '--memory' ../break/break.sh fix.sh
```
```
  --memory 300m --memory-swap 300m --entrypoint python \
  --memory 1g --memory-swap 1g --entrypoint python \
```
(`--memory-swap` equals `--memory`, so the container can't borrow swap space either.) By hand, you can change the limit on the existing container and start it again. It re-runs the same command:
```bash
docker update --memory 1g --memory-swap 1g d06-trainer
docker start d06-trainer
```

## ✅ Verify it yourself
`fix.sh` waited for the training to finish. Read the proof:
```bash
docker logs d06-trainer
```
```
epoch 1/5 ... loading 120 MB
epoch 2/5 ... loading 120 MB
epoch 3/5 ... loading 120 MB
epoch 4/5 ... loading 120 MB
epoch 5/5 ... loading 120 MB
✅ model trained
```
```bash
docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' d06-trainer
```
```
false 0
```
Not killed, and a clean exit code **0**. Now watch the memory live: start the same container again (it keeps its 1 GB limit) and look 3 seconds in:
```bash
docker start d06-trainer
sleep 3; docker stats --no-stream d06-trainer
```
```
d06-trainer
CONTAINER ID   NAME          CPU %     MEM USAGE / LIMIT   MEM %     NET I/O       BLOCK I/O   PIDS
d483fe0b6775   d06-trainer   3.15%     486.4MiB / 1GiB     47.50%    872B / 126B   0B / 0B     1
```
(Your numbers will differ a little.) Already past the old 300 MiB limit and happily running. (Start it again later and `docker logs` will show the six lines twice, once per run.)

## 🎯 Key takeaways
- `--memory` is a hard fence (a cgroup). Go over it and the kernel kills the process, with no warning to the program.
- Exit code **137 = 128 + 9 = SIGKILL**. `OOMKilled=true` in `docker inspect` is the proof it was memory.
- The logs of an OOM kill just *stop*. Absence of an error is itself the clue.
- Set limits from measured usage plus headroom (`docker stats`), and alert on OOM kills.

## 💎 Lifelong lesson
> Exit 137 means someone killed it. Find out who, and why.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
D07: Jupyter can't save your notebook: "permission denied". The container is running, but it isn't allowed to write.
