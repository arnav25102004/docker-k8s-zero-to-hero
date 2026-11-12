# PRD: The Kubernetes Bible (zero to hero, hands-on)

Status: draft v1, 2026-11-12 · Owner: course author · Scope: `kubernetes/`, `00-setup/`, `cheatsheets/kubectl.md`, `tests/scenarios/`

## 1. Goal
A learner with no prior knowledge can start at K00, follow every command exactly as written on a laptop (Docker Desktop + kind, or minikube, or Killercoda), and finish K18 plus the 30 break-and-fix scenarios able to deploy, expose, secure, scale and debug a real app. The instructor can teach it live from the scenarios without improvising fixes.

Success means: **a fresh machine, the README open, and zero "it didn't work for me" moments.**

## 2. Audit findings (2026-11-12)

| # | Finding | Evidence | Severity |
|---|---------|----------|----------|
| A1 | Internal Markdown links are healthy | 458 relative links and anchors checked, 0 broken (the one hit was a checker false positive: GitHub keeps `_` in anchors) | OK |
| A2 | The course never pins the Kubernetes version | `00-setup/kind-cluster.yaml` has no `image:`, so students get whatever node version their `kind` binary defaults to; latest stable is **v1.37.2** | High |
| A3 | metrics-server version drift | K13 lab applies **v0.9.1** from the web; the scenarios add-on (`scenarios/_addons/metrics-server.yaml`) is vendored from **v0.8.0** | Medium |
| A4 | Image pin drift | `redis:7-alpine` (floating) in 5 manifests vs `redis:7.4.12-alpine` (pinned) elsewhere; `nginx:1.27-alpine` vs `1.27.5-alpine`; whoami `v1.10.3` in the self-test vs `v1.10.4` in manifests; `it-tools:2024.10.22` is two years old; Excalidraw is `:latest@sha256` | Medium |
| A5 | Counts disagree | Root README says "38 real-world incidents" (8 Git + 30 K8s, omits 15 Docker) and "38 times" in the banner; `kubernetes/README.md` links "scenarios K01 … K15" but there are 30 | Low, but visible on the first page |
| A6 | Intentional typos exist in manifests (`alpnie`, `excalidrw`, `7ca5393`, `FROM python:latest`) | They are the broken halves of scenarios K02, K30, D05, so they must stay. Any automated "fix typos" pass has to skip `break/` folders | Info |
| A7 | One external link returns 403 from this sandbox | `troubleshoot-kubernetes-like-a-pro` (likely the sandbox proxy; verify from a normal network) | Low |
| A8 | No live verification was possible in the audit sandbox | A nested kind cluster failed in `kubeadm init` here. Every claim of "expected output" in the labs is therefore unverified by this audit | High (process) |
| A9 | Topic coverage to confirm (a first grep was unreliable, so treat as a checklist, not a finding) | `kubectl debug`/ephemeral containers, `kubectl events`, `kubectl diff`, native sidecars (`restartPolicy: Always` on init containers), CRDs and operators, Helm/Kustomize basics, finalizers/stuck-Terminating, in-place Pod resize, image volumes | Medium |

What is already strong and must not be lost: the story → concept → break → investigate → fix → takeaway structure of every scenario, the Showdown app, the Indian-campus flavour, and the test harness.

## 3. Principles
1. **Relatable.** Every concept gets an everyday analogy before any YAML (restaurant, railway station, hostel mess, WhatsApp group, exam hall). No jargon before its analogy.
2. **Funny and interactive.** Each lab has one "wow" the room can do on their phones or in a browser, and one thing to break on purpose.
3. **Light.** Images under ~50 MB where possible, all pre-pullable with one script, nothing needs a cloud account.
4. **Pinned.** Every image, manifest URL and tool version is exact and listed in one place (`VERSIONS.md`). "latest" appears nowhere a student types.
5. **Verified.** A change isn't done until its lab has run on a real kind cluster and the pasted output matches.
6. **Seamless.** Each lab states its prerequisites, its namespace, how to clean up, and what "done" looks like.

## 4. Work plan (executed one at a time, in this order)

### P0: Trust the basics (small, safe)
- [ ] P0.1 Fix the counts in root `README.md` and `kubernetes/README.md` (A5).
- [ ] P0.2 Align the self-test whoami tag to the manifests (A4).
- [ ] P0.3 Add `link-check` and `manifest-lint` scripts under `scripts/` so every later phase can be re-verified (internal links, `kubectl apply --dry-run=client`, shellcheck, skip `break/` typos).

### P1: One pinned, current baseline
- [ ] P1.1 Create `VERSIONS.md`: Kubernetes, kubectl, kind, minikube, metrics-server, Envoy Gateway, Gateway API CRDs, every image and tag.
- [ ] P1.2 Pin `kindest/node` to v1.37.x in `00-setup/kind-cluster.yaml`; add minikube `--kubernetes-version` to match; state the version at the top of K00/K01.
- [ ] P1.3 One metrics-server version everywhere (re-vendor the add-on from a single release, keep the kubelet-TLS flag needed for kind) (A3).
- [ ] P1.4 Replace floating tags (`redis:7-alpine`, `nginx:1.27-alpine`) with exact ones; refresh `preload.sh` and both `IMAGES.md` files to match.
- [ ] P1.5 Re-check every `apiVersion` against v1.37 (deprecations, removed APIs) and every vendored add-on.

### P2: Make it provable
- [ ] P2.1 Run `tests/scenarios/k8s.sh` for all 30 scenarios on a throwaway kind cluster on a real machine or CI; fix whatever fails.
- [ ] P2.2 Add a GitHub Actions workflow: link check, manifest lint, then a kind job that runs the scenario self-tests. A red badge on the README is better than a silent drift.
- [ ] P2.3 Walk K00–K18 end to end and re-capture any "expected output" that differs on v1.37.

### P3: Fill the "bible" gaps (confirm A9 first, then add only what's missing)
Each new item is a short lab or scenario in the existing format, with a funny story and a ≤50 MB image.
- [ ] P3.1 Debugging toolkit lab: `kubectl events`, `describe`, `logs --previous`, `debug` with an ephemeral container, `diff`, `explain`, `auth can-i`.
- [ ] P3.2 Native sidecars (init containers with `restartPolicy: Always`) next to the existing sidecar content.
- [ ] P3.3 Helm and Kustomize in one gentle lab ("same app, three environments").
- [ ] P3.4 CRDs and operators: install one tiny CRD, make a custom object, see a controller react.
- [ ] P3.5 Stuck-`Terminating` and finalizers scenario.
- [ ] P3.6 In-place Pod resize (if stable in v1.37, verify before writing).

### P4: Humanize and polish
- [ ] P4.1 One analogy per lab, and the same cast of characters throughout (Meera, the hostel, the canteen) so the course feels like one story.
- [ ] P4.2 An "instructor mode" box in every scenario: the 3 questions to ask the room, the likely wrong guesses, timing.
- [ ] P4.3 A single "Kubernetes in one page" poster and a refreshed `cheatsheets/kubectl.md`.
- [ ] P4.4 Windows/Mac/Linux/Killercoda gotchas table in `00-setup`.

## 5. Out of scope
Managed cloud clusters (EKS/GKE/AKS), service meshes, CI/CD pipelines, and anything needing a paid account.

## 6. Definition of done (per item)
1. Change made. 2. `scripts/link-check` and manifest lint pass. 3. Where it touches a lab, that lab ran on a real cluster and the README output matches. 4. `VERSIONS.md` updated if a version changed. 5. One commit with a plain-English message.

## 7. Open questions for the author
- Target the cluster most students will use: kind on Docker Desktop (current default), or also minikube/Killercoda as first-class?
- OK to add a GitHub Actions workflow with a kind job (needs Actions enabled on the repo)?
- Keep the Christ University framing in the README, or make the course institution-neutral?
