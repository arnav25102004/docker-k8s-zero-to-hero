# D11 · Priya's portfolio, on localhost only

*It works inside. It's running. And nobody can see it.*

⏱ 10 min · beginner · a tiny portfolio web page served by Python's `http.server` · `-p` port publishing, `127.0.0.1` vs `0.0.0.0`

⬇️ First run downloads about 19 MB (the `python:3.12-alpine` base image). Do it on good Wi-Fi, before the session. The page itself is one file in this folder and makes no network calls.

## 📖 The story
Priya, a 2nd-year CSE student in Bengaluru, has a placement drive next week. She built a small portfolio page, packed it into a Docker image, started it with `-p 8111:8000`, and sent the link to her mentor. The mentor replies in 10 seconds: *"Not loading."* Priya checks: the container is **running**. The port is **published**. She even opens a shell inside and the page loads there. So who is lying?

## 🧠 The concept: why, what, how
A container has its **own private network**, like a flat with its own front door. `-p 8111:8000` tells Docker: *"traffic arriving at my laptop on 8111, carry it into the container, and knock on port 8000."* But the knock arrives at the container's **network address** (something like `172.17.0.4`), not at "itself".

An app chooses which doors it answers via its **bind address**:
- `127.0.0.1` = *"only people already inside this flat"* (also called localhost or loopback)
- `0.0.0.0` = *"anyone who knocks, on any door"*

Priya's server was told `--bind 127.0.0.1`. Inside the container, 127.0.0.1 means "this container". The delivery from the outside comes in on a different door, so it is never answered.

```
your browser ──▶ laptop :8111 ──▶ container's network address :8000 ──▶ ✖ server only listens on 127.0.0.1
                                                                       ✔ (a visitor inside the container can still get in)
```
You met the same idea from the outside in [Lab D01, §4 "The student survival kit"](../../01-first-steps/README.md#-4-the-student-survival-kit-real-apps-one-command-each): there `-p 127.0.0.1:8090:8080` meant "only my own laptop may knock". Today the same wall is built **inside** the container, by accident.

## 🏢 Where you'll meet this at work
- **Dev servers**: Flask, Vite, Rails and many others listen on `127.0.0.1` by default. They work on your laptop and go silent the day they're put in a container (developer).
- **Kubernetes**: the same bug in a Pod. The Pod is `Running`, the Service has endpoints, and still nothing answers (developer, SRE, platform team).
- **"Works from `exec`, fails from outside"** is a classic first-week-on-call mystery (SRE).

## 💥 Break it
```bash
cd break && ./break.sh
```
The room should see the script finish happily ("container is running"). Now open http://localhost:8111 (playground: the port 8111 URL): the browser says the site **can't be reached** (or the connection was reset). Nothing in the script printed an error.

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Ask the page directly.**
```bash
curl localhost:8111
```
```
curl: (56) Recv failure: Connection reset by peer
```
The exact message varies by computer: `Connection reset by peer`, `Empty reply from server` or `Connection refused`. All mean the same thing: nobody answered. The call reached port 8111 on your computer, but nothing inside the container ever answered it.

<details><summary>💡 Hint</summary>
Is the container even alive? And if you could stand <em>inside</em> it, would the page load? Who is the server willing to talk to?
</details>

**2. Is the container alive?**
```bash
docker ps --filter name=d11
```
```
CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS          PORTS                                         NAMES
afd55ed8f01b   d11-portfolio:1.0   "python -m http.serv…"   30 seconds ago   Up 29 seconds   0.0.0.0:8111->8000/tcp, [::]:8111->8000/tcp   d11-portfolio
```
(Column layout varies by Docker version.) `Up`, and the port is published: `8111->8000`. So Docker has done its part.

**3. Stand inside the container and ask again.** `wget` is a tiny download tool that already exists in this image:
```bash
docker exec d11-portfolio wget -qO- http://127.0.0.1:8000 | head -n 6
```
```
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Priya Nair · Portfolio</title>
```
Priya's page is served perfectly **from inside**. So the app is fine; only visitors from outside are turned away.

**4. What did the server say about itself?**
```bash
docker logs d11-portfolio 2>&1 | grep Serving
```
```
Serving HTTP on 127.0.0.1 port 8000 (http://127.0.0.1:8000/) ...
```
"Serving HTTP on **127.0.0.1**". (Without the `grep` you'd also see one line per page request, and they are all from `127.0.0.1`, i.e. the server itself: your `wget` from step 3 and the script's own check. Nobody from outside ever got through.)

**5. Confirm which doors are open.** `netstat` lists what is listening (`-t` TCP, `-l` listening, `-n` numbers):
```bash
docker exec d11-portfolio netstat -tln
```
```
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 127.0.0.1:8000          0.0.0.0:*               LISTEN      
```
Local Address `127.0.0.1:8000`. A server that welcomes everyone would show `0.0.0.0:8000` here.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The `Dockerfile` starts the server with `--bind 127.0.0.1`. Inside a container, that means *"only answer connections coming from this same container"*. Traffic from your laptop, forwarded by `-p`, arrives on the container's network address, which the server isn't listening on, so nobody answers: the connection is reset, empty or refused, depending on your computer. The app is healthy; it is just listening on the wrong door.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: `break/` and `fix/` hold the same page. Only the `Dockerfile` differs:
```bash
grep -n '^CMD' ../break/Dockerfile Dockerfile
```
```
../break/Dockerfile:7:CMD ["python", "-m", "http.server", "8000", "--bind", "127.0.0.1"]
Dockerfile:7:CMD ["python", "-m", "http.server", "8000", "--bind", "0.0.0.0"]
```
`0.0.0.0` means "listen on every network interface". By hand, this replaces `./fix.sh`: remove the old container, rebuild from the fixed `Dockerfile`, run again:
```bash
docker rm -f d11-portfolio
docker build -t d11-portfolio:1.0 .
docker run -d --name d11-portfolio -p 8111:8000 d11-portfolio:1.0
```

## ✅ Verify it yourself
Run these in order, right after the fix:
```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:8111
```
```
200
```
The server now says who it listens for:
```bash
docker logs d11-portfolio 2>&1 | grep Serving
docker exec d11-portfolio netstat -tln
```
```
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 0.0.0.0:8000            0.0.0.0:*               LISTEN      
```
And the page itself:
```bash
curl -s localhost:8111 | grep -o '<title>.*</title>'
```
```
<title>Priya Nair · Portfolio</title>
```
**Now the fun part.** Open http://localhost:8111 (playground: the port 8111 URL). Priya's portfolio loads: her three projects, and a contact line. Send the link to the person next to you. 🎉

## 🎯 Key takeaways
- `-p HOST:CONTAINER` forwards traffic to the container's **network address**, not to "localhost inside the container".
- An app bound to `127.0.0.1` accepts connections **only from inside its own container**. Bind `0.0.0.0` to accept forwarded traffic.
- "Running" and "port published" don't mean "reachable". Test from inside (`docker exec`), then from outside, and compare.
- Check `docker logs` and `netstat -tln`: they show the address the app really listens on.

## 💎 Lifelong lesson
> Inside a container, listen on 0.0.0.0. 127.0.0.1 is a wall.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
[D12](../12-high-score-lost-on-stop/README.md): *You beat the high score. The server restarts. Your name is gone.*
