# D04 · The password that isn't

*You type the right password. VS Code says it's wrong. Who's lying?*

⏱ 10 min · beginner · VS Code in the browser (`codercom/code-server:4.145.2`) · configuration from the environment, `-e`, `docker inspect`

⬇️ First run downloads about 380 MB. Do it on good Wi-Fi, before the session.

## 📖 The story
It's lab day at Christ University. Your team lead pings the group: *"VS Code is up on the shared machine, the password is `change-me-123`."* You open the page, type it carefully, twice, and get **Incorrect password**. Your friend tries. Same. Nobody changed anything... or so everyone thinks. The password is right. VS Code says it's wrong. Who's lying?

## 🧠 The concept: why, what, how
A container image is a *recipe that can't know your secrets*. The same image runs on your laptop, in the college lab and in production, so settings like passwords and database addresses are handed in from outside when the container starts: **environment variables**, passed with `-e NAME=value`.

Think of a breakfast cafe: the kitchen (the app) can cook anything, but it only knows *this* customer's order if someone writes it on the ticket (`-e`). No ticket, no order.

- The app **reads** `PASSWORD` from its environment when it starts.
- If it isn't there, many apps don't crash: they quietly fall back to a **default**.
- Here the default is a **random password**, generated and saved inside the container in `~/.config/code-server/config.yaml`. It's the app being helpful, and it's why nobody sees an error.

## 🏢 Where you'll meet this at work
- **A missing `DATABASE_URL` in production**: the app starts, then talks to the wrong (or no) database (developer, SRE).
- **A `.env` file that never reached the server**: it was on your laptop, not in the deploy (developer, platform team).
- **Kubernetes Secrets not mounted**: the pod runs, but the secret never arrived (SRE, platform team).

## 💥 Break it
```bash
cd break && ./break.sh
```
VS Code starts and asks for a password. Laptop: open http://localhost:8104. Playground: open the port 8104 URL. Type `change-me-123`. The page stays on the login screen and shows a red **Incorrect password**. (Try it once or twice only: code-server blocks a browser after a few wrong attempts.)

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Prove the symptom from the terminal.** The browser says "wrong"; what does the server actually say?
```bash
curl -s -o /dev/null -w '%{http_code}\n' --data-urlencode password=change-me-123 localhost:8104/login
```
```
200
```
A successful login would answer with a redirect (`302`). `200` means "here is the login page again".

<details><summary>💡 Hint</summary>
Nobody told this container the password. So where did the password VS Code is checking come from? Read what the app says about itself when it starts.
</details>

**2. Read what the app says about itself.**
```bash
docker logs d04-vscode
```
```
[...] info  Wrote default config file to /home/coder/.config/code-server/config.yaml
[...] info  HTTP server listening on http://0.0.0.0:8080/
[...] info    - Authentication is enabled
[...] info      - Using password from /home/coder/.config/code-server/config.yaml
```
(shortened.) Look at the last line: the password comes from a **file**, not from `$PASSWORD`. Compare with the fixed run later.

**3. What did we actually hand this container?**
```bash
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' d04-vscode
```
```
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LANG=en_US.UTF-8
ENTRYPOINTD=/entrypoint.d
USER=coder

```
Look for a `PASSWORD=` line. There isn't one: those four are only the image's own defaults.

**4. Ask the container directly.**
```bash
docker exec d04-vscode printenv PASSWORD
```
(Prints nothing, and the command fails with exit code 1.)

**5. So whose password is VS Code checking?**
```bash
docker exec d04-vscode cat /home/coder/.config/code-server/config.yaml
```
```
bind-addr: 127.0.0.1:8080
auth: password
password: 63b8f9592c5a5a56c2f7c35b
cert: false
```
There it is: a random password VS Code made up for itself. (Yours will be a different string.) Nothing here is `change-me-123`.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

`PASSWORD` was never passed to the container (`docker run` had no `-e PASSWORD=...`). Without it, code-server generated its own random password and saved it in `config.yaml`. VS Code was not lying: it was checking a password nobody knew.
</details>

## 🔧 Fix it
```bash
cd ../fix && ./fix.sh
```
What changed: one `-e` flag on the `docker run` line. The two lines side by side (`break.sh` first, `fix.sh` second):
```bash
grep -h -o -e '-p 8104:8080.*"$IMAGE"' ../break/break.sh fix.sh
```
```
-p 8104:8080 "$IMAGE"
-p 8104:8080 -e PASSWORD=change-me-123 "$IMAGE"
```
By hand: environment can't be changed on a running container, so remove it and run it again with the flag:
```bash
docker rm -f d04-vscode
docker run -d --name d04-vscode -p 8104:8080 -e PASSWORD=change-me-123 codercom/code-server:4.145.2
```

## ✅ Verify it yourself
Open http://localhost:8104 (playground: the port 8104 URL) and log in with `change-me-123`. VS Code opens. Then:
```bash
docker exec d04-vscode printenv PASSWORD
```
```
change-me-123
```
```bash
docker logs d04-vscode | grep -i "password"
```
```
[...] info      - Using password from $PASSWORD
```
(shortened.) The log line now says `$PASSWORD`, not the config file. And the same test as before:
```bash
curl -s -o /dev/null -w '%{http_code}\n' --data-urlencode password=change-me-123 localhost:8104/login
```
```
302
```

## 🎯 Key takeaways
- Settings reach a container from outside: `-e NAME=value` (or an env file, or a Secret).
- A missing setting often doesn't crash the app: it silently uses a default, here a random password.
- `docker inspect` shows what the container was *given*; `docker exec ... printenv` shows what it *sees*.
- Environment is fixed when a container is created: to change it, recreate the container.

## 💎 Lifelong lesson
> If it's not in `docker inspect`, the app never got it.

## 🧹 Clean up
```bash
cd .. && ./cleanup.sh
```

## Next →
[D05](../05-image-tag-typo/README.md): An image tag with a one-character typo, and a container that never starts.
