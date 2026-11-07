# D13 · The portfolio that disappears

*The website is in the image. You can prove it. And it's gone.*

⏱ 12 min · beginner · Priya's portfolio page again, served by nginx · bind mounts, what a mount does to the folder underneath, named volumes

⬇️ First run downloads about 23 MB (the `nginx:1.27.5-alpine` base image). Do it on good Wi-Fi, before the session. The page itself is one file in this folder and makes no network calls.

🪟 Windows with WSL: keep this repo inside the Linux filesystem (`~/…`), not under `/mnt/c/…`. Bind mounts from `/mnt/c` are slow and can behave differently; the scripts build an absolute path from their own location, which works best on the Linux side.

## 📖 The story
Priya's portfolio is back, now served by **nginx** and packed into a Docker image. Last week her teammate Ravi said: *"Mount a folder so we can edit the page live, no rebuild!"* So the container was started with a `-v` flag, pointing at a folder of team notes. Today the placement drive link goes out and the page shows **403 Forbidden**. The image was built an hour ago, with the website inside. Priya even re-built it twice, just in case. Nothing changed. Where did her portfolio go?

## 🧠 The concept: why, what, how
A **bind mount** (`-v /some/folder:/path/in/container`) puts a folder from your laptop at a path inside the container. It is how you edit code live, and how you hand a config file to a container.

The surprise: a mount **covers** whatever the image already had at that path. It does **not** merge. Think of a **notice board in a hostel corridor**: if someone pins a big chart board over it, you see only the chart. The old notices are still there underneath, but you can't see them, and nginx can't either.

- The image keeps its files (`index.html` is still in the image).
- The container sees only the mounted folder, as long as the mount is there.
- Remove the mount, and the original files appear again.

A **named volume** (`-v myvolume:/path`) is different in one friendly way: the **first time** Docker uses a brand-new, empty volume, it **copies** the image's files from that path into it. A bind mount never does that.

```
image:      /usr/share/nginx/html/ ─ index.html, 50x.html
bind mount: dev-notes/ ──────────────▶ covers it ─▶ container sees only TODO.txt ─▶ nginx: no index.html ─▶ 403
```

## 🏢 Where you'll meet this at work
- **Config mounts hiding defaults**: you mount your own `conf.d/` folder and the image's default config files vanish (developer, platform team).
- **`node_modules` hidden by a source mount**: `-v $(pwd):/app` covers the `node_modules` that `npm install` put in the image, and the app can't find its packages (developer).
- **Kubernetes ConfigMap mounts**: mounting a ConfigMap on a directory replaces the whole directory, not just one file (SRE, platform team).

## 💥 Break it
```bash
cd break && ./break.sh
```
The script builds the image (website inside) and starts it the way Ravi suggested, with a live-edit folder mounted. The room should see the script finish happily, with no error. Now open http://localhost:8113 (playground: the port 8113 URL): the browser shows **403 Forbidden**, with the word nginx at the bottom.

## 🔍 Investigate
Guess first, then run these **in order**. (Column layouts of `docker` commands vary a little by Docker version; yours may look slightly different.)

**1. What does the server say?**
```bash
curl -I localhost:8113
```
```
HTTP/1.1 403 Forbidden
Server: nginx/1.27.5
Date: Sat, 07 Nov 2026 18:41:33 GMT
Content-Type: text/html
Content-Length: 153
Connection: keep-alive
```
(shortened: the `Date` line differs on your computer.) **403 Forbidden**, not "can't be reached". nginx is up and answering. It just refuses to show anything.

<details><summary>💡 Hint</summary>
nginx shows a folder's <code>index.html</code>. A 403 here means: the folder is there, but there is no <code>index.html</code> in it. Is the website really where nginx is looking?
</details>

**2. Look in the folder nginx serves.**
```bash
docker exec d13-site ls /usr/share/nginx/html
```
```
TODO.txt
```
Only `TODO.txt`. No `index.html`, no `50x.html`. This is the folder nginx serves, and the website is not in it. The log says the same:
```bash
docker logs d13-site 2>&1 | grep error
```
```
2026/11/07 18:41:33 [error] 32#32: *2 directory index of "/usr/share/nginx/html/" is forbidden, client: 172.17.0.1, server: localhost, request: "HEAD / HTTP/1.1", host: "localhost:8113"
```
(Your times and numbers will differ.)

**3. Where did `TODO.txt` come from? Ask Docker how the container was started.**
```bash
docker inspect -f '{{json .Mounts}}' d13-site
```
```
[{"Type":"bind","Source":"/Users/you/…/13-portfolio-disappears/break/dev-notes","Destination":"/usr/share/nginx/html","Mode":"","RW":true,"Propagation":"rprivate"}]
```
(shortened: your `Source` path is different.) A **bind** mount: a folder from the laptop (`dev-notes`) sits exactly on `/usr/share/nginx/html`.

**4. Is the website still in the image? Start a fresh container from the same image, with no mount.**
```bash
docker run --rm d13-site:1.0 ls /usr/share/nginx/html
```
```
50x.html
index.html
```
There it is. The website **is** in the image. It was never deleted. It is just covered.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The bind mount `dev-notes/ → /usr/share/nginx/html` **covers** the image's folder. A mount doesn't add files to what is there, it replaces the whole view of that path. The container saw only `TODO.txt`, so nginx found no `index.html` and answered 403. The files in the image were never touched.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: the image and the page are identical in `break/` and `fix/`. Only the `docker run` differs: the `-v` line is gone.
```bash
grep -n -- '-v "' ../break/break.sh fix.sh
```
```
../break/break.sh:24:  -v "$HERE/dev-notes:/usr/share/nginx/html" d13-site:1.0 >/dev/null \
```
`fix.sh` has no such line. By hand, this replaces `./fix.sh`: remove the old container and run the same image without the mount.
```bash
docker rm -f d13-site
docker run -d --name d13-site -p 8113:80 d13-site:1.0
```
(If you still want live edits, mount your folder on a **different** path, or mount the whole site folder, so nothing important is covered.)

## ✅ Verify it yourself
Run these in order, right after the fix:
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:8113
```
```
200
```
Open http://localhost:8113 (playground: the port 8113 URL): Priya Nair's portfolio is back. Now check that the container has no mounts, and that the folder holds the website again:
```bash
docker inspect -f '{{json .Mounts}}' d13-site
docker exec d13-site ls /usr/share/nginx/html
```
```
[]
50x.html
index.html
```
Bonus, the friendly cousin: a **named volume** starts out as a copy of the image's folder. Try it:
```bash
docker volume create d13-demo
docker run --rm -v d13-demo:/usr/share/nginx/html d13-site:1.0 ls /usr/share/nginx/html
```
```
d13-demo
50x.html
index.html
```
Same path, same kind of `-v`, but the files show up. (Only the first time, and only for a volume that starts empty. Remove it with `docker volume rm d13-demo`, or run the cleanup below.)

## 🎯 Key takeaways
- A bind mount **covers** what the image has at that path. It doesn't merge.
- The image is fine; `docker run --rm IMAGE ls PATH` shows what is really inside it.
- `docker inspect -f '{{json .Mounts}}' NAME` lists every mount on a container. Check it whenever files "disappear".
- A brand-new **named volume** is filled from the image on first use; a bind mount never is.

## 💎 Lifelong lesson
> A mount doesn't add, it replaces. Know what you're covering.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
[D14](../14-leaked-api-key/README.md): The leaked API key. You never pushed the key to GitHub. You pushed it inside the image.
