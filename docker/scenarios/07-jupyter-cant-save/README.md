# D07 · "Permission denied"

*Two hours of notebook work. You press Save. "Permission denied."*

⏱ 12 min · beginner · Jupyter image (`quay.io/jupyter/base-notebook:2026-11-02`) · users and file owners, volumes, `chown`

⬇️ First run downloads about 343 MB (the same image as D01 and D06, so it may already be on your laptop) plus a 2 MB helper image (`busybox:1.36`). Do it before the session anyway.

## 📖 The story
It's assignment week at Christ University. You keep your notebooks in a Docker volume so nothing is lost when the container is replaced. Last month, an old backup job set up a folder called `assignments` in that volume. Today you write for two hours, press Save, and Jupyter says **Permission denied**. The container is up. The disk is not full. Your teammate says, *"Restart it."* You restart it. Same error.

## 🧠 The concept: why, what, how
Every process in a container runs as a **user**, a number called a UID. Jupyter runs as `jovyan`, UID **1000**, on purpose: it's safer than running as root. Every file and folder has an **owner** (also a number) and a set of permissions.

Think of a hostel with room keys. A room keyed to the warden (root) won't open for you, even though it's in your own corridor.

- A **volume** keeps files outside the container, so they survive restarts. The files keep their owner numbers.
- A folder created by root has owner `0` and mode `755`: everyone can *read* it, only root can *write* to it.
- Jupyter (UID 1000) is "everyone else" for that folder. It can look, not save.
- The fix is not "run Jupyter as root". It is to make the **owner** match the **user**.

## 🏢 Where you'll meet this at work
- **Volumes shared between jobs** that run as different users (a root backup job and a normal app): the classic one (developer, SRE).
- **NFS or network disks** where the files belong to someone else's UID (platform team).
- **Kubernetes** `securityContext.fsGroup` or an `initContainer` that runs `chown`: the same fix, written in YAML (SRE, platform team).

## 💥 Break it
```bash
cd break && ./break.sh
```
Jupyter starts normally and the container stays up. Open http://localhost:8107/lab?token=change-me-123 (playground: the port 8107 URL + `/lab?token=change-me-123`). In the file browser open **work**, then **assignments**. It looks normal and empty. Click the **Python 3 (ipykernel)** tile under *Notebook* to create a notebook there. A dialog pops up:

> **Error**: Permission denied: work/assignments/Untitled.ipynb

No notebook appears. (Creating or saving anything else inside `assignments` fails the same way.)

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Is the container healthy?**
```bash
docker ps --filter name=d07
```
```
CONTAINER ID   IMAGE                                      COMMAND                  CREATED         STATUS                   PORTS                                         NAMES
a3e397ce0040   quay.io/jupyter/base-notebook:2026-11-02   "tini -g -- start.sh…"   7 seconds ago   Up 7 seconds (healthy)   0.0.0.0:8107->8888/tcp, [::]:8107->8888/tcp   d07-jupyter
```
Up and healthy. Nothing crashed. The problem is not "is it running" but "what is it allowed to do".

<details><summary>💡 Hint</summary>
"Permission denied" is about <b>who</b> is asking and <b>who</b> owns the thing. Two questions: which user is Jupyter running as? And who owns the <code>assignments</code> folder? Do the two numbers match?
</details>

**2. Who is Jupyter running as?**
```bash
docker exec d07-jupyter id
```
```
uid=1000(jovyan) gid=100(users) groups=100(users)
```
UID **1000**, GID **100**. That's the user doing the saving.

**3. Who owns the folders in the volume?** (`-n` shows numbers instead of names, which is what Linux really compares.)
```bash
docker exec d07-jupyter ls -ln /home/jovyan/work
```
```
total 4
drwxr-xr-x 2 0 0 4096 Nov  7 18:03 assignments
```
`assignments` is owned by `0 0`: root. Mode `drwxr-xr-x` means only the owner may write. Jupyter is UID 1000, so it is locked out.

**4. Where does this folder actually live?**
```bash
docker volume inspect d07-notebooks
```
```
[
    {
        "CreatedAt": "2026-11-07T18:03:29Z",
        "Driver": "local",
        "Labels": {
            "z2h.scenario": "d07"
        },
        "Mountpoint": "/var/lib/docker/volumes/d07-notebooks/_data",
        "Name": "d07-notebooks",
        "Options": null,
        "Scope": "local"
    }
]
```
(Your date will differ.) The files live in a Docker volume, outside the container. A new container would mount the *same* files with the *same* owners: replacing the container can't fix this. The data has to change.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The `assignments` folder was created by a root process, so it is owned by **uid 0**, mode `755`. Jupyter runs as **uid 1000** (`jovyan`), so it can read the folder but not write to it. The folder lives in the volume, so the wrong owner survives restarts.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: ownership of the data, not the app. The setup made `assignments` as root; the fix hands the whole volume to uid 1000, gid 100:
```bash
grep -h 'mkdir' ../break/break.sh
grep -h 'chown -R' fix.sh
```
```
  sh -c 'chown 1000:100 /data && mkdir /data/assignments && chown 0:0 /data/assignments && chmod 755 /data/assignments' \
docker run --rm --label z2h.scenario=d07 -v d07-notebooks:/data "$HELPER" chown -R 1000:100 /data \
```
By hand it is two commands: a one-off root container (busybox) that changes the owner, then a restart:
```bash
docker run --rm -v d07-notebooks:/data busybox:1.36 chown -R 1000:100 /data
docker restart d07-jupyter
```
(Going back to running Jupyter as root, or `chmod 777`, would also "work". Don't: make the owner match the user.)

## ✅ Verify it yourself
Run these **in order**, right after `fix.sh`.

**1. Save a notebook in the UI.** Open http://localhost:8107/lab?token=change-me-123 (playground: the port 8107 URL + `/lab?token=change-me-123`), go to **work / assignments**, and click the **Python 3 (ipykernel)** tile. This time `Untitled.ipynb` appears in the file list.

**2. Now the command-line proof.** This prints nothing when it works:
```bash
docker exec d07-jupyter touch /home/jovyan/work/assignments/test.ipynb
```
**3. Who owns the files now?**
```bash
docker exec d07-jupyter ls -ln /home/jovyan/work/assignments
```
```
total 4
-rw-r--r-- 1 1000 100 72 Nov  7 18:04 Untitled.ipynb
-rw-r--r-- 1 1000 100  0 Nov  7 18:04 test.ipynb
```
Owner `1000 100`: the same numbers as `id` showed. (Skipped step 1? Then you'll see only `test.ipynb`.)
```bash
docker exec d07-jupyter ls -ln /home/jovyan/work
```
```
total 4
drwxr-xr-x 3 1000 100 4096 Nov  7 18:04 assignments
```
The folder that said `0 0` now says `1000 100`.

## 🎯 Key takeaways
- A container runs as a user (a UID). Files in a volume have an owner (a UID). Writing needs the two to agree.
- "Permission denied" while the container is healthy usually means a user/owner mismatch. Check `id` and `ls -ln`.
- Volumes keep owners across restarts, so a root-created folder keeps locking Jupyter out until the data is fixed.
- Fix the **ownership** (`chown`), not the user (no root, no `chmod 777`).

## 💎 Lifelong lesson
> Every file has an owner and every process has a user. Make them agree.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
[D08](../08-it-tools-unhealthy/README.md): it-tools is running and answers every request, but Docker says it's **unhealthy**. The app works; who is lying?
