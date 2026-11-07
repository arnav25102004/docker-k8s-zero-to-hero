# D14 · The leaked API key

*You never pushed the key to GitHub. You pushed it inside the image.*

⏱ 12 min · beginner · a tiny "Bengaluru weather" widget in Python · image layers, `docker history`, build secrets

⬇️ First run downloads about 19 MB (the `python:3.12-alpine` base image). Do it on good Wi-Fi, before the session. The widget prints a made-up forecast and makes no network calls.

🔑 **The key in this demo is fake on purpose:** `z2h-demo-key-NOT-REAL-123`. It opens nothing. **Never use a real key, token or password in class**, not even "just to try it". If you ever do, treat it as leaked and rotate it.

🔧 Needs BuildKit, which is the default builder in modern Docker (Docker Desktop and Docker Engine 23 and newer). You don't have to switch anything on.

## 📖 The story
Meera is building a weather widget for the campus fest app. The weather service wants an **API key**, and the demo is in ten minutes. Her quick hack: pass the key into the build and save it in a config file inside the image, so it "just works". She is careful, she keeps the key out of her Git repo. The widget runs. She shares the image with the team so everybody can try it. Ravi asks, half joking: *"Meera, is that your key I can read?"*

## 🧠 The concept: why, what, how
An image is not one blob. It is a **stack of layers**, one per Dockerfile step, and Docker also saves a **history**: the exact command behind every layer, with its arguments. That history travels with the image, so anyone who can pull the image can read it.

- A build **`ARG`** is "a value you hand to the build". Any `RUN` step that uses it is saved in the history **with the value filled in**.
- A **file written during the build** (like `/app/config`) is part of a layer, so it is in the image too.
- A **build secret** (`RUN --mount=type=secret`) is different: it is shown to one `RUN` step in a temporary spot and then gone. It is never written into a layer or the history.

Think of a **password written into every printed answer booklet**: whoever gets a booklet gets the password.

```
 docker build --build-arg KEY=...          docker build --secret ...
   ARG KEY ─▶ RUN echo $KEY > config         RUN --mount=type=secret ...
        │            │                              │
        ▼            ▼                              ▼
   history says KEY=...   layer holds the file    nothing saved ✔
```

## 🏢 Where you'll meet this at work
- **Leaked cloud keys in public images:** someone pushes an image to Docker Hub with an AWS key in its history. Bots scan for these within minutes (developer, then a very bad day for the security team).
- **Scanners in the pipeline:** tools like `docker scout`, Trivy and GitGuardian read image layers and history to catch secrets before release (platform team, DevSecOps).
- **Key rotation drills:** when a key might have leaked, the answer is never "delete the image", it is "rotate the key": issue a new one and kill the old one (SRE, security).

## 💥 Break it
```bash
cd break && ./break.sh
```
The room should see a normal, happy build: the widget runs and prints a Bengaluru forecast, and the image gets a second name, `d14-weather:shared`, as if it were sent to the team. Nothing is red. (Docker may print a yellow warning about `SecretsUsedInArgOrEnv` while building. Most people scroll past it.) Notice that the widget started without anyone passing it a key.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Run the widget yourself.** No key given this time:
```bash
docker run --rm d14-weather:broken
```
```
Bengaluru weather widget
  Key accepted: z2h-demo...
  Today: 27 C, light rain after 4 pm. Carry an umbrella.
  (Demo forecast: this app makes no network calls.)
```
It says *"Key accepted"*, but we never passed one with `-e`. So where did it get the key? It must already be inside the image.

<details><summary>💡 Hint</summary>
An image remembers how it was built. Which command shows every step that made an image, and the exact text of each step?
</details>

**2. Read the image's history.** One line per build step, newest on top:
```bash
docker history d14-weather:broken
```
```
IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
824d9ef28387   About a minute ago   CMD ["python" "weather.py"]                     0B        buildkit.dockerfile.v0
<missing>      About a minute ago   RUN |1 WEATHER_API_KEY=z2h-demo-key-NOT-REAL…   12.3kB    buildkit.dockerfile.v0
<missing>      About a minute ago   ARG WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123   0B        buildkit.dockerfile.v0
<missing>      About a minute ago   COPY weather.py . # buildkit                    12.3kB    buildkit.dockerfile.v0
```
(shortened: the real list continues with Python's own steps, and your IDs, times and column layout differ by Docker version.) There is the build `ARG`, with its value, in plain sight. The `RUN` line is cut short with `…`.

**3. Stop it cutting things short.** Ask for the full text, and keep only the lines that contain the key:
```bash
docker history --no-trunc d14-weather:broken | grep z2h-demo-key
```
```
<missing>   About a minute ago   RUN |1 WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123 /bin/sh -c echo "key=$WEATHER_API_KEY" > /app/config # buildkit
<missing>   About a minute ago   ARG WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123
```
(shortened: the real lines have wide gaps between the columns.) Two lines: the `ARG`, and the `RUN` that wrote the key into `/app/config`.

**4. Is it in `docker inspect`?** Inspect is where we usually look for settings (ENV and so on):
```bash
docker inspect d14-weather:broken | grep -i demo-key
```
Nothing prints. A build `ARG` is **not** an `ENV`, so it isn't in the image's settings. But it's still in the history, so don't relax.

**5. Is it in a file too?** The `RUN` line wrote `/app/config`. Read it from a throwaway container:
```bash
docker run --rm d14-weather:broken cat /app/config
```
```
key=z2h-demo-key-NOT-REAL-123
```
So the key leaks **twice**: in the history, and in a file inside the image.

**6. Does the team's copy leak too?** `d14-weather:shared` is the same image under a second name:
```bash
docker history --no-trunc d14-weather:shared | grep -c z2h-demo-key
```
```
2
```
Anyone who can pull the image can run these same two commands. No password, no hacking.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The Dockerfile takes the key as a build **`ARG`** and uses it in a **`RUN`** step. Docker saves every step in the image's history **with the argument's value filled in**, and the `RUN` also wrote the key into `/app/config`, which is part of a layer. Meera kept the key out of Git, but the image is just as shareable as the repo, and it carries the key.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: `break/` and `fix/` hold the same app. Only the `Dockerfile` differs. These are the lines that matter:
```bash
grep -n -E '^(ARG|RUN)' ../break/Dockerfile Dockerfile
```
```
../break/Dockerfile:5:ARG WEATHER_API_KEY
../break/Dockerfile:7:RUN echo "key=$WEATHER_API_KEY" > /app/config
Dockerfile:7:RUN --mount=type=secret,id=weather_key \
```
The `ARG` is gone, and nothing writes the key to a file any more. The build gets the key as a **secret** that only one `RUN` step can see, and the running app gets its key at **runtime** with `-e`. By hand (this replaces `./fix.sh`):
```bash
export WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123
docker build --secret id=weather_key,env=WEATHER_API_KEY -t d14-weather:fixed .
docker run --rm -e WEATHER_API_KEY d14-weather:fixed
```
(`env=WEATHER_API_KEY` means "take the secret from my shell variable of that name". `-e WEATHER_API_KEY` with no `=` passes that variable's value on to the container.)

Two honest notes. First, the build secret here is cosmetic: the `RUN` only checks that a key exists. The real fix is simply **not putting the key in the image at all**. `RUN --mount=type=secret` is for builds that genuinely need a secret (for example `pip install` from a private package index), and the check step stands in for that. Second, `-e` keeps the key out of the **image**, not out of sight: `docker inspect` on the container shows it (see Verify), and typing the key inline lands in your shell history. In production, use a secrets manager or file-based secrets (Docker, Compose or Kubernetes secrets).

## ✅ Verify it yourself
The same search that found the key before:
```bash
docker history --no-trunc d14-weather:fixed | grep z2h-demo-key
```
It prints **nothing**. Is the key in a file? The image has only the app:
```bash
docker run --rm d14-weather:fixed ls /app
docker run --rm d14-weather:fixed cat /app/config
```
```
weather.py
cat: can't open '/app/config': No such file or directory
```
Does the widget really need the key at runtime? Run it without one, then with one:
```bash
docker run --rm d14-weather:fixed
docker run --rm -e WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123 d14-weather:fixed
```
```
No WEATHER_API_KEY set. The widget needs a key to start.
Run it with:  docker run --rm -e WEATHER_API_KEY=<your key> <image>
Bengaluru weather widget
  Key accepted: z2h-demo...
  Today: 27 C, light rain after 4 pm. Carry an umbrella.
  (Demo forecast: this app makes no network calls.)
```
The flip side of `-e`: the key is visible on the **container**. Start one and inspect it:
```bash
docker run --name d14-demo -e WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123 d14-weather:fixed >/dev/null
docker inspect d14-demo --format '{{.Config.Env}}'
docker rm d14-demo
```
```
[WEATHER_API_KEY=z2h-demo-key-NOT-REAL-123 PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305 PYTHON_VERSION=3.12.16 PYTHON_SHA256=b5796915dc45ff745cfb4e990a7e7c93d6f546328a102ce31448d69ebc37575c]
d14-demo
```
(The order and extra settings can differ.) It is in the container's settings, not in the shared image. That is better, but it is not a vault.

One last look. The old image is **still leaky**; fixing the Dockerfile does not repair images that were already shared:
```bash
docker history --no-trunc d14-weather:shared | grep -c z2h-demo-key
```
```
2
```
That is why a real leak means **rotating the key**, not just rebuilding.

## 🎯 Key takeaways
- Every build step is saved as a layer, with its command and arguments, and anyone who can pull the image can read them (`docker history --no-trunc`).
- A build `ARG` used in a `RUN` is recorded with its value. Files written during the build are in the image too.
- Use **build secrets** (`--secret` and `RUN --mount=type=secret`) for things the build needs, and **runtime** configuration for things the app needs. `-e` keeps the key out of the image but not out of `docker inspect` or shell history, so in production use a secrets manager or file-based secrets.
- If a key might have leaked, **rotate it**. Deleting the image does not un-leak a key.

## 💎 Lifelong lesson
> If it's in the image, it's public. Secrets travel separately.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```
This also removes every `d14-weather` image tag.

## Next →
D15: Compose start order. Everything starts. Nothing works. Run it again… and it works?!
