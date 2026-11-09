# D07 · "Permission denied"

*Two hours of notebook work. You press Save. "Permission denied."*

⏱ 12 min · beginner · Jupyter image (`quay.io/jupyter/base-notebook:2026-11-02`) and `busybox:1.36`, in a `compose.yaml` · volumes, users and file owners, `user:`, `chown`

⬇️ First run downloads about 343 MB (the same Jupyter image as D01 and D06, so it may already be on your laptop) plus a 2 MB helper image (`busybox:1.36`). Do it before the session anyway.

All commands below run from this scenario's folder (`docker/scenarios/07-jupyter-cant-save`). On Git Bash for Windows, `MSYS_NO_PATHCONV=1` is already set by the scripts; if you type `docker` commands with `/paths` yourself, run `export MSYS_NO_PATHCONV=1` first.

## 📖 The story
It's assignment week at Christ University. Lakshmi keeps her notebooks in a Docker volume so nothing is lost when the container is replaced. A nightly backup job shares that volume and sets up a folder called `assignments` in it. Today she writes for two hours, presses Save, and Jupyter says **Permission denied**. The container is up. The disk is not full. Her teammate Ravi says, *"Restart it."* She restarts it. Same error.

## 🧠 The concept: why, what, how
Every process in a container runs as a **user**, and Linux knows users by a number, the **UID**. Every file and folder has an **owner** (also a number) and **permission bits** saying who may read and who may write.

Think of a hostel with room keys. A room keyed to one person opens only for that person, even if it sits in your own corridor.

- A **volume** keeps files outside the container, so they survive restarts and replacements. The files keep their owner numbers.
- Linux does not compare names, it compares numbers: "is the process's UID the owner's UID?"
- A **compose file** can set which user a service runs as with `user:`. If it doesn't, the image decides.
- Two services can mount the same volume. They share the *files*, not the *identity*.

## 🏢 Where you'll meet this at work
- **A nightly job and an app sharing one volume**: the classic "it worked yesterday" ticket (developer, SRE).
- **NFS or network disks** where files belong to someone else's UID (platform team).
- **Kubernetes pods** that mount the same persistent volume: the same "Permission denied" with a different YAML (SRE, platform team).

## 💥 Break it
By hand: copy the `break/` folder to `work/` (this is the folder you will edit), then start it.
```bash
rm -rf work && cp -R break work
docker compose -f work/compose.yaml up -d
```
(`rm -rf work` clears any old copy, so this is safe to repeat.) Or the one-line shortcut, which prints exactly these commands (after a cleanup):
```bash
./break/break.sh
```
```
▶ $ rm -rf work && cp -R break work
▶ $ docker compose -f work/compose.yaml up -d
 Container d07-jupyter-1 Started
 Container d07-backup-1 Started
⏳ Waiting for Jupyter to start .. ✔ ready
⏳ Waiting for the backup job to finish  ✔ ready
```
(shortened)

Open http://localhost:8107/lab?token=change-me-123 (playground: the port 8107 URL + `/lab?token=change-me-123`). In the file browser open **work**, then **assignments**. It looks normal. Click the **Python 3 (ipykernel)** tile under *Notebook* to create a notebook there. A dialog pops up:

> **Error**: Permission denied: work/assignments/Untitled.ipynb

(Creating or saving anything else inside `assignments` fails the same way.)

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is everything running?** Start with the big picture: what does Docker say about both services?
```bash
docker compose -f work/compose.yaml ps -a
```
```
NAME            IMAGE                                      COMMAND                  SERVICE   CREATED          STATUS                      PORTS
d07-backup-1    busybox:1.36                               "sh -c 'mkdir -p /da…"   backup    14 seconds ago   Exited (0) 14 seconds ago   
d07-jupyter-1   quay.io/jupyter/base-notebook:2026-11-02   "tini -g -- start.sh…"   jupyter   14 seconds ago   Up 14 seconds (healthy)     0.0.0.0:8107->8888/tcp, [::]:8107->8888/tcp
```
Jupyter is up and healthy. `backup` shows **Exited (0)**: that is expected. It is a one-shot job that does its work and stops, and 0 means success. Nothing crashed. The question is not "is it running" but "what is each one allowed to do".

<details><summary>💡 Hint</summary>
"Permission denied" is about <b>who</b> is asking and <b>who</b> owns the thing. Which user is Jupyter running as? Who owns the <code>assignments</code> folder? And which service created that folder, as which user? Do the numbers match?
</details>

**2. What did we write?** Next, read the file Docker was given: both services, side by side.
```bash
cat work/compose.yaml
```
```
# D07: a notebook server and the nightly backup job share one volume.
name: d07

services:
  jupyter:
    image: quay.io/jupyter/base-notebook:2026-11-02
    command: start-notebook.py --IdentityProvider.token=change-me-123
    ports:
      - "8107:8888"
    volumes:
      - notebooks:/home/jovyan/work

  # A one-shot job: it does its work and exits. "Exited (0)" is its normal ending.
  backup:
    image: busybox:1.36
    command: sh -c "mkdir -p /data/assignments && echo 'nightly backup folder' > /data/assignments/backup-note.txt"
    volumes:
      - notebooks:/data
    depends_on:
      - jupyter

volumes:
  notebooks:
```
Both services mount the **same volume**, `notebooks`. Look for a `user:` line under either service. (The `backup` job writes the `assignments` folder, as you can read in its `command`.)

**3. Who is Jupyter running as?** Now ask the running container, not the file.
```bash
docker compose -f work/compose.yaml exec jupyter id
```
```
uid=1000(jovyan) gid=100(users) groups=100(users)
```
UID **1000**, GID **100**. This is `jovyan`, the normal user the Jupyter image is built to run as, on purpose: it is safer than root. This is the user doing the saving.

**4. Who owns the folders?** (`-n` shows numbers instead of names, which is what Linux really compares.)
```bash
docker compose -f work/compose.yaml exec jupyter ls -ln work
docker compose -f work/compose.yaml exec jupyter ls -ln work/assignments
```
```
total 4
drwxr-sr-x 2 0 100 4096 Nov  9 10:10 assignments
```
```
total 4
-rw-r--r-- 1 0 100 22 Nov  9 10:10 backup-note.txt
```
Owner **0** on both: not 1000. Mode `drwxr-sr-x` means only the owner may write into the folder. Prove it with the same action Save performs:
```bash
docker compose -f work/compose.yaml exec jupyter touch work/assignments/test.ipynb
```
```
touch: cannot touch 'work/assignments/test.ipynb': Permission denied
```

**5. Who is the backup job?** The job exited, so ask a fresh copy of it who it is (`run --rm` starts a one-off container and deletes it afterwards).
```bash
docker compose -f work/compose.yaml run --rm backup id
```
```
 Container d07-jupyter-1 Running 
 Container d07-backup-run-1ed78b5273da Creating 
 Container d07-backup-run-1ed78b5273da Created 
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```
(The container name after `backup-run-` is random; yours will differ.) The backup job is **uid 0**. Same number as the owner of `assignments`.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The `backup` service has no `user:` line, so it runs as the image's default user, which for `busybox` is **root (uid 0)**. It created `assignments` in the shared volume, so root owns the folder, with mode `755`: everyone can read, only root can write. Jupyter runs as **uid 1000** (`jovyan`), so it can look but not save. The folder lives in a volume, so the wrong owner survives restarts, and a restart of Jupyter changes nothing.
</details>

## 🔧 Fix it
Two changes: fix the **data** that is already wrong, and fix the **job** so it can't do it again. First, what the fixed file changes:
```bash
diff break/compose.yaml fix/compose.yaml
```
```
15a16
>     user: "1000:100"
```
**By hand.** First, hand the files in the volume to uid 1000 / gid 100 using a one-off root container (`--user root` overrides the job's user just for this run):
```bash
docker compose -f work/compose.yaml run --rm --user root backup chown -R 1000:100 /data
```
Then edit `work/compose.yaml`: under `backup:`, right below `image: busybox:1.36`, add the line `user: "1000:100"` (same indentation as `image:`). Check that you match the fixed file, and apply it:
```bash
diff fix/compose.yaml work/compose.yaml && echo same-as-fix
docker compose -f work/compose.yaml up -d
```
```
same-as-fix
 Container d07-jupyter-1 Running 
 Container d07-backup-1 Recreate 
 Container d07-backup-1 Recreated 
 Container d07-backup-1 Starting 
 Container d07-backup-1 Started 
```
Compose recreated only `backup` and ran it again, this time as 1000:100. Jupyter was not touched or restarted.

**Or run the shortcut**, which copies `fix/` into `work/` and does the same, printing each command:
```bash
./fix/fix.sh
```
(Going back to running Jupyter as root, or `chmod 777`, would also "work". Don't: make the owner match the user.)

## ✅ Verify it yourself
Run these **in order**, right after the fix.

**1. Save a notebook in the UI.** Open http://localhost:8107/lab?token=change-me-123, go to **work / assignments**, and click the **Python 3 (ipykernel)** tile. This time `Untitled.ipynb` appears.

**2. Now the command-line proof.** It prints nothing when it works:
```bash
docker compose -f work/compose.yaml exec jupyter touch work/assignments/test.ipynb
```
**3. Who owns the files now?**
```bash
docker compose -f work/compose.yaml exec jupyter ls -ln work
docker compose -f work/compose.yaml exec jupyter ls -ln work/assignments
```
```
total 4
drwxr-sr-x 2 1000 100 4096 Nov  9 10:11 assignments
```
```
total 4
-rw-r--r-- 1 1000 100 22 Nov  9 10:11 backup-note.txt
-rw-r--r-- 1 1000 100  0 Nov  9 10:11 test.ipynb
```
Owner `1000 100`: the same numbers `id` showed. (If you did step 1, `Untitled.ipynb` is listed too.) Run `docker compose -f work/compose.yaml up -d` again whenever you like: the job now runs as 1000:100 each time, and the folder stays yours.

## 🎯 Key takeaways
- A container runs as a user (a UID). Files in a volume have an owner (a UID). Writing needs the two to agree.
- Two services sharing a volume share files, not identity. Check each one with `id`.
- "Permission denied" while the container is healthy usually means a user/owner mismatch. Check `id` and `ls -ln`.
- Fix the **ownership** (`chown`) and the **job's** `user:`, not Jupyter (no root, no `chmod 777`).

## 💎 Lifelong lesson
> Every file has an owner and every process has a user. Make them agree.

## 🧹 Clean up
```bash
./cleanup.sh
```

## Next →
[D08](../08-it-tools-unhealthy/README.md): it-tools is running and answers every request, but Docker says it's **unhealthy**. The app works; who is lying?
