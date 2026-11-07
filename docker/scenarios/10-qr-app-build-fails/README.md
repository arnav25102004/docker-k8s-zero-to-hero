# D10 · Build your own QR code app

*The file is RIGHT THERE. Docker says it doesn't exist.*

⏱ 10 min · beginner · nginx + a tiny "Make your own QR code" page · build context, `.dockerignore`

⬇️ First run downloads about 23 MB (the nginx base image). Do it on good Wi-Fi, before the session. Everything else is already in this folder, and the page makes no network calls at all.

## 📖 The story
Your club has a fest stall, and everybody wants a QR code for their GitHub or LinkedIn page. You wrote a small web page that draws one as you type, and packed it into a Docker image. It built fine last week. This morning a teammate "cleaned up" a file called `.dockerignore`, and now the build stops with: *"/qrcode.min.js": not found*. You open the folder. The file is sitting right there.

## 🧠 The concept: why, what, how
When you run `docker build .`, Docker does **not** look at your folder directly. First your computer packs up the folder (the **build context**) and sends it to the builder. Only then do the `COPY` lines run, and they can only see what is in that package.

A file called **`.dockerignore`** is the filter between the two: anything it lists is left out of the package. It's useful (keep `node_modules/` and secrets out, keep builds fast), but a pattern that is too greedy removes files you need.

Think of a courier collecting a parcel from your hostel room: you can point at a thing on your shelf, but if it never went into the box, the person at the other end will never see it.

```
your folder ──▶ .dockerignore filter ──▶ build context (the box) ──▶ COPY lines
   (all files)     "*.js"  removes JS         qrcode.min.js is missing ✖
```

## 🏢 Where you'll meet this at work
- **CI pipelines that suddenly fail** after someone tidies `.dockerignore`, while "it still builds on my laptop" because of a cache (developer, platform team).
- **Huge build contexts**: a forgotten `node_modules/` or `.git` folder gets sent every build and makes it slow (everyone).
- **Secrets**: `.dockerignore` is also how `.env` files are kept out of images (security team, developer).

## 💥 Break it
```bash
cd break && ./break.sh
```
The room should see a wall of red text: `docker build` stops with an error, and then `docker run` complains that the image `d10-qr:1.0` can't be found. Nothing is running at http://localhost:8110 (playground: the port 8110 URL) because the app was never built.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Read the error.** Scroll up in what `break.sh` printed. The important lines (shortened):
```
#7 [3/4] COPY qrcode.min.js /usr/share/nginx/html/qrcode.min.js
#7 ERROR: failed to calculate checksum of ref ...: "/qrcode.min.js": not found
...
   3 | >>> COPY qrcode.min.js /usr/share/nginx/html/qrcode.min.js
ERROR: failed to build: failed to solve: ... "/qrcode.min.js": not found
```
Step 3 of 4 failed: Docker says `/qrcode.min.js` doesn't exist. (The two lines before it, `index.html` and the base image, were fine.)

**2. Is the file really missing?** Look at the folder:
```bash
ls
```
```
Dockerfile    LICENSE       break.sh      index.html    qrcode.min.js
```
It's right there, next to the `Dockerfile`. So Docker and you are looking at **different things**.

<details><summary>💡 Hint</summary>
Docker doesn't read your folder, it reads a package your computer sends to it. Is there a file that decides what goes into that package? It starts with a dot, so <code>ls</code> hides it. Try <code>ls -a</code>.
</details>

**3. What else is in this folder?** Show the hidden files too:
```bash
ls -a
```
```
.              .dockerignore  LICENSE        index.html
..             Dockerfile     break.sh       qrcode.min.js
```
(The order of the names can differ on your computer.) A `.dockerignore`.

**4. What does it say?**
```bash
cat .dockerignore
```
```
*.js
```
One line: leave out every file ending in `.js`. `qrcode.min.js` ends in `.js`.

**5. Does Docker agree?** Build again with the full, plain log, and look at the start:
```bash
docker build --progress=plain -t d10-qr:1.0 .
```
```
#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 211B done
#1 WARN: CopyIgnoredFile: Attempting to Copy file "qrcode.min.js" that is excluded by .dockerignore (line 3)
...
#3 [internal] load .dockerignore
#3 transferring context: 45B done
```
(shortened) Newer Docker even warns you: the file you `COPY` is **excluded by `.dockerignore`**. Older Docker only says "not found", which is why you needed steps 2 to 4.

Last check: is there any image to run?
```bash
docker images d10-qr
```
```
IMAGE   ID             DISK USAGE   CONTENT SIZE   EXTRA
```
Just the header: no image was built.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

`.dockerignore` contains `*.js` ("someone excluded test files"). That also matches `qrcode.min.js`, so the file never goes into the **build context**. `COPY qrcode.min.js` then looks for it in the context, doesn't find it, and the build fails. The file exists on your disk, but not in what Docker was sent.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: `break/` and `fix/` hold the same app. Only `.dockerignore` differs:
```bash
diff -r ../break . | grep -v "^Only in"
```
```
diff --color -r ../break/.dockerignore ./.dockerignore
1c1,2
< *.js
---
> *.test.js
> node_modules/
```
(The first line may read just `diff -r ...` without `--color` on your computer.) Now it leaves out only test files (`*.test.js`) and the huge `node_modules/` folder, and `qrcode.min.js` goes through. By hand, the fix is to edit `.dockerignore` and build again:
```bash
printf '*.test.js\nnode_modules/\n' > .dockerignore
docker build -t d10-qr:1.0 .
docker run -d --name d10-qr -p 8110:80 d10-qr:1.0
```

## ✅ Verify it yourself
```bash
docker images d10-qr
```
```
IMAGE        ID             DISK USAGE   CONTENT SIZE   EXTRA
d10-qr:1.0   8762c8ce3003         76MB         21.8MB   U
```
(Your ID and columns will differ.) The image exists now. Is the app running, and does it answer?
```bash
docker ps --filter name=d10-qr
curl -s -o /dev/null -w '%{http_code}\n' localhost:8110
```
```
CONTAINER ID   IMAGE        COMMAND                  CREATED        STATUS        PORTS                                     NAMES
a58a0cb9c213   d10-qr:1.0   "/docker-entrypoint.…"   1 second ago   Up 1 second   0.0.0.0:8110->80/tcp, [::]:8110->80/tcp   d10-qr
200
```
And the file that was "missing" is now inside the image:
```bash
docker exec d10-qr ls /usr/share/nginx/html
curl -s localhost:8110/qrcode.min.js | head -c 60
```
```
50x.html
LICENSE
index.html
qrcode.min.js
var qrcode=function(){function i(t,r){function a(t,r){g=func
```
The page loads only its own files, nothing from the internet:
```bash
curl -s localhost:8110 | grep -o 'src="[^"]*"'
```
```
src="qrcode.min.js"
```

**Now the fun part.** Open http://localhost:8110 (playground: the port 8110 URL). Replace the text with **your own GitHub or LinkedIn URL**; the QR code redraws as you type. Hold up your phone, **scan the QR code from the screen**, and see your profile open. 📱

## 🎯 Key takeaways
- `docker build` sends a **build context** to the builder. `COPY` can only use files inside it.
- **`.dockerignore` filters the context first.** A greedy pattern like `*.js` silently removes real files.
- "Not found" for a file you can see usually means "not in the context": check `.dockerignore` (use `ls -a`, it's hidden).
- A good `.dockerignore` keeps `node_modules/`, `.git` and secrets out, making builds faster and safer. Be specific.

## 💎 Lifelong lesson
> What Docker sees is not what you see. Check the context.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Credits
The QR code is drawn by [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) 1.4.4 by Kazuhiko Arase, MIT licensed (the `LICENSE` file sits next to it in each folder). `qrcode.min.js` comes from https://cdnjs.cloudflare.com/ajax/libs/qrcode-generator/1.4.4/qrcode.min.js, and the license text from the project's GitHub repository. The unminified `qrcode.js` of the same version on https://unpkg.com/qrcode-generator@1.4.4/qrcode.js is byte-identical to the one on cdnjs.

## Next →
D11: Portfolio on localhost only. It works inside. It's running. And nobody can see it.
