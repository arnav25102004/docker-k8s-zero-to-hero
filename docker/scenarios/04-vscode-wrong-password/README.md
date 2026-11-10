# D04 · The password that isn't

*The settings file says `change-me-123`. VS Code says "Incorrect password". Who's lying?*

⏱ 10 min · beginner · VS Code in the browser (`codercom/code-server:4.145.2`) · `--env-file`, `docker exec ... env`, why env changes need a new container

⬇️ First run downloads about 380 MB (`codercom/code-server:4.145.2`). Do it on good Wi-Fi, before the session.

## 📖 The story
It's lab day at Christ University. Your team lead pings the group: *"VS Code is up on the shared machine. The password is in `app.env`: `change-me-123`."* You open the page, type it carefully, twice, and get **Incorrect password**. Your friend tries. Same. The settings file is right there. The password is right. VS Code says it's wrong. Who's lying?

## 🧠 The concept: why, what, how
A container image is a *recipe that can't know your secrets*. The same image runs on your laptop, in the college lab and in production, so settings like passwords and database addresses are handed in from outside when the container starts, as **environment variables**.

Think of a breakfast cafe: the kitchen (the app) can cook anything, but it only knows *this* customer's order if someone writes it on the ticket.

- One variable at a time: `docker run -e NAME=value`.
- Many at once: put them in a file of `NAME=value` lines and pass `--env-file app.env`. Docker reads the file **when the container is created** and copies the lines into the container's environment.
- The app reads its settings from its environment when it starts.

## 🏢 Where you'll meet this at work
- **A `.env` file that never changed what the app sees**: the app starts, then talks to the wrong (or no) database (developer, SRE).
- **A config file edited, but the service never recreated**: the old settings keep running (platform team).
- **Kubernetes Secrets or ConfigMaps not mounted**: the pod runs, but the setting never arrived (SRE, platform team).

## 💥 Break it
> 🪟 Git Bash on Windows: run `export MSYS_NO_PATHCONV=1` once in this terminal before typing any command below (the scripts already set it for themselves).
> 🐢 First run on this machine? `docker run` first prints `Unable to find image '…' locally` and a few download lines, then the container ID. That's normal, not an error.

Work from this scenario's folder (`docker/scenarios/04-vscode-wrong-password`). The settings file `break/app.env` is yours to read. First make your own working copy (`./cleanup.sh` first is safe at any time and makes a repeat run start clean), then start VS Code with it:
```bash
./cleanup.sh
rm -rf work && cp -R break work
docker run -d --name d04-vscode -p 8104:8080 --env-file work/app.env codercom/code-server:4.145.2
```

Shortcut: `./break/break.sh` does the same and prints every command it runs. It always starts from a fresh `work/` (which also holds a copy of the script; ignore it).

VS Code starts and asks for a password. Laptop: open http://localhost:8104. Playground: open the port 8104 URL. Type `change-me-123`. The page stays on the login screen with a red **Incorrect password**. (Try it once or twice only: code-server slows down a browser after a few wrong attempts.)

## 🔍 Investigate
Guess first, then run these **in order**.

**1. Prove the symptom from the terminal.** The browser says "wrong"; what does the server actually answer?
```bash
curl -s -o /dev/null -w '%{http_code}\n' --data-urlencode password=change-me-123 localhost:8104/login
```
```
200
```
A successful login answers with a redirect (`302`). `200` means "here is the login page again".

<details><summary>💡 Hint</summary>
The password VS Code is checking has to come from somewhere. Where did this container get its settings, and what does the app say about where it found its password?
</details>

**2. Read what the app says about itself.** Why next: the server's own log tells us where it got the password.
```bash
docker logs d04-vscode
```
```
[...] info  Wrote default config file to /home/coder/.config/code-server/config.yaml
[...] info  code-server 4.145.2 302bc77436721f5a474e06d1fe34cf8f86195d5e
[...] info  Using user-data-dir /home/coder/.local/share/code-server
[...] info  Using config file /home/coder/.config/code-server/config.yaml
[...] info  HTTP server listening on http://0.0.0.0:8080/
[...] info    - Authentication is enabled
[...] info      - Using password from /home/coder/.config/code-server/config.yaml
[...] info    - Not serving HTTPS
[...] info  Session server listening on /home/coder/.local/share/code-server/code-server-ipc.sock
Failed login attempt {"remoteAddress":"172.17.0.1","userAgent":"curl/8.7.1","timestamp":1794219032}
```
(Timestamps shortened to `[...]`. Your last line has a different timestamp.) Look at "Using password from": a **file**, not `$PASSWORD`. And "Wrote default config file" means code-server had to create its own settings.

**3. What did we write in the settings file?** Why next: the file is what we handed to Docker, so read it.
```bash
cat work/app.env
```
```
# Settings for the VS Code container (read by: docker run --env-file)
PASSWROD=change-me-123
```
Read the name on the left of the `=` slowly, letter by letter.

**4. What does the container actually see?** Why next: the file is what we meant; the container's environment is what it got.
```bash
docker exec d04-vscode env | grep -i pass
```
```
PASSWROD=change-me-123
```
Docker copied the line faithfully. Now ask for the exact name the app wants:
```bash
docker exec d04-vscode printenv PASSWORD
```
(Prints nothing, and the command exits with code 1.)

**5. So whose password is VS Code checking?** Why next: if it isn't ours, there must be another one.
```bash
docker exec d04-vscode cat /home/coder/.config/code-server/config.yaml
```
```
bind-addr: 127.0.0.1:8080
auth: password
password: 21d9e5a0275b3df0e766ca02
cert: false
```
A random password VS Code made up for itself. (Yours will be a different string.) Nothing here is `change-me-123`.

## 🩺 Root cause
<details><summary>Reveal after the room guesses</summary>

The key in `app.env` is spelled `PASSWROD`, not `PASSWORD`. Docker passed it along without complaint (it has no idea which names an app wants), but code-server only looks for `PASSWORD`. Many apps don't crash when a setting is missing: they quietly fall back to a **default**. Not finding `PASSWORD`, code-server made up a random password, saved it in `config.yaml` inside the container, and used that. That is why nobody saw an error. VS Code was not lying: it was checking a password nobody knew.
</details>

## 🔧 Fix it
What changed: one line in `app.env`. Compare the broken file with the fixed one:
```bash
diff break/app.env fix/app.env
```
```
2c2
< PASSWROD=change-me-123
---
> PASSWORD=change-me-123
```
By hand: open `work/app.env` in your editor and correct the key. (Or from the terminal: `sed 's/PASSWROD/PASSWORD/' work/app.env > work/app.env.new && mv work/app.env.new work/app.env`.) Check it:
```bash
cat work/app.env
```
```
# Settings for the VS Code container (read by: docker run --env-file)
PASSWORD=change-me-123
```
The file is fixed, but the container was created from the old one. Does a restart pick it up?
```bash
docker restart d04-vscode
```
```
d04-vscode
```
(`docker restart` just echoes the container name.) Now ask again:
```bash
docker exec d04-vscode printenv PASSWORD
```
(Still prints nothing, exit code 1.) Docker reads `--env-file` **once, when the container is created**. A restart keeps the same environment. So remove the container and create a new one:
```bash
docker rm -f d04-vscode
docker run -d --name d04-vscode -p 8104:8080 --env-file work/app.env codercom/code-server:4.145.2
```

Or run `./fix/fix.sh`, which does the same: it copies `fix/` into a fresh `work/`, removes the container and runs it again, printing each command.

## ✅ Verify it yourself
Open http://localhost:8104 (playground: the port 8104 URL) and log in with `change-me-123`. VS Code opens. Then:
```bash
docker exec d04-vscode printenv PASSWORD
```
```
change-me-123
```
```bash
docker logs d04-vscode | grep -i password
```
```
[...] info      - Using password from $PASSWORD
```
The log line now says `$PASSWORD`, not the config file. And the same test as before:
```bash
curl -s -o /dev/null -w '%{http_code}\n' --data-urlencode password=change-me-123 localhost:8104/login
```
```
302
```
One honest detail: `config.yaml` inside the container still holds a random password.
```bash
docker exec d04-vscode cat /home/coder/.config/code-server/config.yaml
```
```
bind-addr: 127.0.0.1:8080
auth: password
password: 90c5afc6a55d38b3ebd3c138
cert: false
```
code-server writes that file on first start no matter what. Now that `PASSWORD` is set, it is simply ignored (the log line above tells you which one wins).

## 🎯 Key takeaways
- `--env-file app.env` copies its `NAME=value` lines into the container's environment, once, when the container is created.
- Docker does not know which names an app expects: a misspelled key is passed along without any error.
- A missing setting often doesn't crash the app: it silently uses a default, here a random password.
- Read both sides: `cat` the file (what you wrote) and `docker exec ... env` (what the container sees).
- Changing the file does nothing to a running container, and `docker restart` doesn't help: remove it and run it again.

## 💎 Lifelong lesson
> Docker passes on what you wrote, not what you meant.

## 🧹 Clean up
```bash
./cleanup.sh
```
Removes the container and the `work/` folder.

## Next →
[D05](../05-image-tag-typo/README.md): *One letter. That's all it takes to break a deploy.*
