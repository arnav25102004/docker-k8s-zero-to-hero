# Lab D11: Resource Limits & Container Security

> ⏱ 45 min · 🟡 Intermediate → 🔴 Advanced

## 🎯 What you'll learn
- Limit memory and CPU, and see what an **OOM kill** looks like
- Why containers should not run as root, and how to prove one isn't
- Drop Linux capabilities, read-only filesystems, `no-new-privileges`
- A hardened `docker run` you can reuse

## 🧠 Concept in 60 seconds
Containers are **processes** on a shared kernel, isolated with Linux **namespaces** (what you can see) and **cgroups** (how much you can use). Without limits, one container can use all of the host's memory and take down its neighbours. Without hardening, a compromised container has a much easier path to the host.

## 🧪 Hands-on

### Part A: Memory limits and OOMKilled 💥
```bash
docker run --name hog --memory 64m --memory-swap 64m python:3.12-alpine \
  python -c "x = bytearray(200 * 1024 * 1024); print('allocated!')"
echo "exit code: $?"
docker inspect hog --format 'OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}}'
```
Expected: `OOMKilled=true ExitCode=137`. The kernel killed the process because it went over its memory limit. Note that the app printed **no error**: it was killed from outside. Exit code 137 plus `OOMKilled=true` is the signature to remember.

Now give it enough memory:
```bash
docker rm hog
docker run --rm --memory 300m python:3.12-alpine python -c "x = bytearray(200*1024*1024); print('allocated!')"
```

### Part B: CPU limits
```bash
docker run -d --name burner --cpus 0.5 -p 8080:8080 z2h/api:1.0
curl -s "localhost:8080/api/burn?seconds=10" >/dev/null &
sleep 3; docker stats --no-stream burner      # CPU % stays near 50%
wait; docker rm -f burner
```
🔍 CPU limits **throttle** (the app gets slower); memory limits **kill**. Kubernetes behaves the same way (Lab K09).

### Part C: Who am I inside the container?
```bash
docker run --rm alpine id                              # uid=0(root)
docker run --rm z2h/api:1.0 id                         # uid=10001: our Dockerfile sets USER
docker run --rm --user 1234:1234 alpine id             # override at runtime
```
Why it matters, demonstrated:
```bash
docker run --rm -v /tmp:/host-tmp alpine sh -c 'touch /host-tmp/created-by-container-root && ls -l /host-tmp/created-by-container-root'
rm -f /tmp/created-by-container-root
```
Root in a container with a host mount can write host files as root (on Linux hosts). If an attacker breaks out of the container, they arrive as root.

### Part D: Capabilities
Root in a container has a *reduced* set of Linux capabilities. Drop all of them, then add back only what's needed:
```bash
docker run --rm alpine sh -c 'chown nobody /etc/hostname && echo "chown worked"'
docker run --rm --cap-drop ALL alpine sh -c 'chown nobody /etc/hostname && echo "chown worked"'    # Operation not permitted
```
Most web apps need **no** capabilities when they listen on a port above 1024.

### Part E: Read-only root filesystem
```bash
docker run --rm --read-only alpine sh -c 'echo x > /etc/x'                 # Read-only file system
docker run --rm --read-only --tmpfs /tmp alpine sh -c 'echo x > /tmp/x && echo "tmp is writable"'
```
An attacker who gets in can't install tools or modify binaries.

### Part F: The hardened run 🛡
```bash
docker run -d --name hardened -p 8080:8080 \
  --user 10001:10001 \
  --read-only --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --memory 128m --cpus 0.5 --pids-limit 100 \
  --restart unless-stopped \
  z2h/api:1.0
sleep 2; curl -s localhost:8080/healthz && echo " ← works with every restriction on"
docker rm -f hardened
```
Each flag maps directly to a Kubernetes `securityContext` / `resources` field (Labs K09 and K16):

| docker run | Kubernetes |
|---|---|
| `--user 10001` | `runAsUser: 10001`, `runAsNonRoot: true` |
| `--read-only` | `readOnlyRootFilesystem: true` |
| `--cap-drop ALL` | `capabilities: { drop: ["ALL"] }` |
| `no-new-privileges` | `allowPrivilegeEscalation: false` |
| `--memory`, `--cpus` | `resources.limits` |

### Part G: Things that should make you nervous 🚩
| Flag | Why it's dangerous |
|---|---|
| `--privileged` | disables almost all isolation; effectively root on the host |
| `-v /var/run/docker.sock:/var/run/docker.sock` | full control of the Docker engine = root on the host |
| `--network host` | no network isolation |
| `--pid host` | can see and signal every host process |

## 🏭 In production
- Always set memory limits. A memory leak should kill **one container**, not the host.
- Platform teams enforce these settings with policy (Kubernetes Pod Security Standards, Kyverno, OPA Gatekeeper) so individual developers don't have to remember them.

## ✅ Checkpoint
<details><summary>1. A container exits with code 137. Name two possible causes and how to tell them apart.</summary>

OOM kill, or someone or something sent SIGKILL (`docker kill`, or `docker stop` after its timeout). Check `docker inspect --format '{{.State.OOMKilled}}'`.
</details>
<details><summary>2. Exceeding a CPU limit vs exceeding a memory limit: what happens in each case?</summary>

CPU is compressible: the process is throttled and gets slower. Memory is not: the process is killed.
</details>

## 🧹 Cleanup
```bash
docker rm -f hog burner hardened 2>/dev/null
```

🎉 **Docker track complete!** Test yourself with the [Docker break-and-fix scenarios](../scenarios/README.md) (D06 is the OOM kill you just learned about), then move on to [Kubernetes](../../kubernetes/README.md).
