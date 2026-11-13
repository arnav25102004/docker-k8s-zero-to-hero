"""Shared helpers for the Kubernetes break/fix scenarios (plain Python 3, standard library only).

Every scenario's run.py (in break/ and fix/) and cleanup.py imports this file and then reads
top to bottom like a recipe: check the cluster, create a namespace, apply the YAML, wait
for the symptom, say "the scene is set".

    import scenario_lib as z

It talks to the cluster only through the `kubectl` you already have, so it works on any
cluster (kind, minikube, Docker Desktop, a playground) and on Windows, macOS and Linux.
"""
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(LIB_DIR))

# Windows consoles are often cp1252; the messages use emoji, so force UTF-8 output.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass


# ---------------------------------------------------------------- messages --
def say(msg):
    print("\033[1;36m▶ %s\033[0m" % msg, flush=True)


def ok(msg):
    print("\033[1;32m✔ %s\033[0m" % msg, flush=True)


def warn(msg):
    print("\033[1;33m⚠ %s\033[0m" % msg, flush=True)


def die(msg):
    print("\033[1;31m✖ %s\033[0m" % msg, flush=True)
    sys.exit(1)


def scene_set():
    """The one line every break ends with. It gives no clue: finding the cause is the exercise."""
    print("\n\033[1;32m✅ The scene is set.\033[0m Open the scenario README and start investigating.")


def show_next(first, *commands):
    """The closing block of a fix: what you should see, then what to type to check it."""
    print("\n\033[1m👀 What you should see now\033[0m")
    print("   " + first)
    if commands:
        print("\n\033[1m👉 Next\033[0m")
        for command in commands:
            print("   " + command)


# ----------------------------------------------------------------- kubectl --
def kubectl(*args, input_text=None):
    """Run kubectl quietly. Returns (exit_code, stdout). Never raises."""
    try:
        done = subprocess.run(["kubectl", *args], input=input_text, capture_output=True,
                              text=True, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return 127, ""
    return done.returncode, done.stdout


def kubectl_all(*args):
    """Like kubectl(), but returns (exit_code, stdout and stderr together): for error messages."""
    try:
        done = subprocess.run(["kubectl", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return 127, ""
    return done.returncode, (done.stdout + done.stderr).strip()


def kubectl_ok(*args):
    """True when the kubectl command succeeds."""
    return kubectl(*args)[0] == 0


def kubectl_out(*args):
    """The command's output, stripped ("" when it fails)."""
    code, out = kubectl(*args)
    return out.strip() if code == 0 else ""


def kubectl_show(*args):
    """Run kubectl with its output visible. Returns the exit code."""
    return subprocess.call(["kubectl", *args])


def need_cluster():
    """Stop early, with one friendly line, when there is no usable cluster."""
    if shutil.which("kubectl") is None:
        die("kubectl isn't installed. See 00-setup.")
    if not kubectl_ok("get", "--raw", "/readyz"):
        die("Can't reach a Kubernetes cluster. Check: kubectl config current-context")


def apply_files(*paths):
    """kubectl apply -f <path> [-f <path> ...]. Stops the scenario if it fails."""
    args = ["apply"]
    for path in paths:
        args += ["-f", path]
    if kubectl(*args)[0] != 0:
        die("kubectl apply failed. Is the cluster healthy?")


def apply_dir(folder):
    """kubectl apply -f <folder>/  (every YAML file in it)."""
    apply_files(folder + os.sep)


def wait_for(description, seconds, check):
    """Poll check() once a second (it returns True when ready). Returns True or False."""
    if os.environ.get("Z2H_CHECK_ONCE"):  # test hook (tests/scenarios/compare-py-sh.py): look once, never wait
        _safe(check)
        return True
    print("⏳ Waiting for %s " % description, end="", flush=True)
    for _ in range(seconds):
        if _safe(check):
            print(" ", end="")
            ok("ready")
            return True
        print(".", end="", flush=True)
        time.sleep(1)
    if _safe(check):
        print(" ", end="")
        ok("ready")
        return True
    print()
    warn("%s still not ready after %ss" % (description, seconds))
    return False


def _safe(check):
    try:
        return bool(check())
    except Exception:  # a flaky kubectl answer is "not yet", never a crash
        return False


# -------------------------------------------------------------- namespaces --
def delete_ns(*names):
    """Delete namespaces and wait (up to 120 s each) until they are really gone."""
    for name in names:
        kubectl("delete", "namespace", name, "--ignore-not-found", "--wait=false")
        for _ in range(120):
            if not kubectl_ok("get", "namespace", name):
                break
            time.sleep(1)
        if kubectl_ok("get", "namespace", name):
            warn("Namespace %s is still terminating after 120s. Check: kubectl get namespace %s" % (name, name))


def scenario_id(namespace):
    """k-08-oomkilled -> k08 (the label every scenario namespace carries)."""
    return "k" + namespace[2:].split("-")[0]


def taint_left_over():
    """True while S2.3's z2h-vip taint is still on a node (it would leave every Pod Pending)."""
    out = kubectl_out("get", "nodes", "-o",
                      r'jsonpath={range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}')
    return "z2h-vip" in out.split()


def fresh_ns(*names):
    """Delete (and wait for) then create each namespace. Returns False if it cannot."""
    if taint_left_over():
        die("The nodes still carry the z2h-vip taint from S2.3. Run its cleanup (python3 cleanup.py "
            "in kubernetes/scenarios/2-workloads/3-watchman-skipped-a-gate), or: kubectl taint nodes --all z2h-vip-")
    for name in names:
        delete_ns(name)
        if kubectl("create", "namespace", name)[0] != 0:
            return False
        if kubectl("label", "namespace", name, "z2h.scenario=" + scenario_id(name), "--overwrite")[0] != 0:
            return False
        # The "default" ServiceAccount appears a moment later; Pods created straight away are refused.
        for _ in range(30):
            if kubectl_ok("get", "serviceaccount", "default", "-n", name):
                break
            time.sleep(1)
        else:
            return False
    return True


def stop_port_forwards(*names):
    """Stop leftover `kubectl port-forward -n NS ...` processes (Linux and macOS)."""
    if shutil.which("pkill") is None:
        return
    for name in names:
        subprocess.call(["pkill", "-f", "port-forward -n " + name],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def port_free(port):
    """True if nothing on this computer listens on the port; otherwise explain and return False."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(1)
        if probe.connect_ex(("127.0.0.1", int(port))) != 0:
            return True
    warn("Port %s is already used by another program on your computer (maybe a kubectl port-forward)." % port)
    print('   Stop it ("pkill -f port-forward", or Ctrl+C in the terminal running it), or close that program, then run this again.')
    return False


# --------------------------------------------------------------- scenarios --
def cleanup(*names):
    """Stop port-forwards and delete the scenario's namespaces. Never fails."""
    stop_port_forwards(*names)
    delete_ns(*names)
    if any(kubectl_ok("get", "namespace", name) for name in names):
        return
    print("✅ Scenario %s cleaned up" % scenario_id(names[0]))


def cleanup_start():
    """First line of every cleanup.py: nothing to do if there is no cluster."""
    if not kubectl_ok("get", "--raw", "/readyz"):
        warn("Can't reach the cluster: nothing to clean up.")
        sys.exit(0)


def run_cleanup(scenario_dir):
    """Run the scenario's own cleanup.py (break runs it first, so every try starts clean)."""
    script = os.path.join(scenario_dir, "cleanup.py")
    subprocess.call([sys.executable, script], stdout=subprocess.DEVNULL)


def create_showdown_configmap(namespace):
    """ConfigMap showdown-code (app.py + index.html), built from apps/api so the code is never copied."""
    api = os.path.join(REPO, "apps", "api")
    code, _ = kubectl("create", "configmap", "showdown-code", "-n", namespace,
                      "--from-file=app.py=" + os.path.join(api, "app.py"),
                      "--from-file=index.html=" + os.path.join(api, "static", "index.html"))
    return code == 0


def pod_reason(namespace, selector):
    """The first Pod's waiting reason, else the last terminated reason, else its phase."""
    base = ["get", "pods", "-n", namespace, "-l", selector, "-o"]
    for path in ("{.items[0].status.containerStatuses[0].state.waiting.reason}",
                 "{.items[0].status.containerStatuses[0].lastState.terminated.reason}",
                 "{.items[0].status.phase}"):
        answer = kubectl_out(*base, "jsonpath=" + path)
        if answer:
            return answer
    return ""


def pod_phase(namespace, name):
    return kubectl_out("get", "pod", name, "-n", namespace, "-o", "jsonpath={.status.phase}")


def pod_count(namespace, selector):
    """How many Pods match the selector right now."""
    out = kubectl_out("get", "pods", "-n", namespace, "-l", selector, "--no-headers")
    return len([line for line in out.splitlines() if line.strip()])


def rolled_out(namespace, deployment):
    """True when `kubectl rollout status` says the Deployment is fully rolled out."""
    return kubectl_ok("rollout", "status", "deployment/" + deployment, "-n", namespace, "--timeout=2s")


def logs_contain(namespace, text, *selector_args):
    """True if the logs of the selected Pod(s) contain the text (selector_args go to kubectl logs)."""
    code, out = kubectl("logs", "-n", namespace, *selector_args)
    return text in out


def events_contain(namespace, text):
    return text in kubectl_out("get", "events", "-n", namespace)


def visitor_running(namespace):
    """True when the small `visitor` Pod (it asks the app for a page every few seconds) is Running."""
    return pod_phase(namespace, "visitor") == "Running"


def visitor_failing(namespace):
    """True when the visitor's latest lines show a ❌ (the app is failing as a user would see it)."""
    return logs_contain(namespace, "❌", "visitor", "--tail=3")


def pods_exist(namespace, selector, at_least=2):
    """True when at least this many Pods match the selector (they exist, ready or not)."""
    out = kubectl_out("get", "pods", "-n", namespace, "-l", selector, "-o", "name")
    return len([line for line in out.splitlines() if line.strip()]) >= at_least


def only_one_pod(namespace, selector):
    """True when exactly one Pod matches (the old Pod is gone after a rollout)."""
    return pod_count(namespace, selector) == 1


def must_wait(description, seconds, check, failure):
    """wait_for, but stop the scenario with a clear message if it never happens."""
    if not wait_for(description, seconds, check):
        die(failure)


def wait_visitor(namespace):
    must_wait("the visitor to start", 180, lambda: visitor_running(namespace),
              "The visitor Pod didn't start. Run cleanup.py and try again.")


def start_break(scenario_dir, namespaces, port=None):
    """The opening of every break: cluster up, clean slate, port free, fresh namespace(s)."""
    need_cluster()
    run_cleanup(scenario_dir)
    if port is not None and not port_free(port):
        die("Port %s is busy, so this scenario can't start. Free it (see above) and run break again." % port)
    if not fresh_ns(*namespaces):
        die("Could not create the namespace %s." % " and ".join(namespaces))


def forward_hint(namespace, service, port):
    """The standard 'check it in your browser' line shown after a fix."""
    return ("kubectl port-forward -n %s svc/%s %s:80   (in a second terminal; then open http://localhost:%s; "
            "on a playground add --address 0.0.0.0 and open the URL for port %s)" % (namespace, service, port, port, port))


def check_rollouts(*namespaces, quiet=False):
    """True when every Deployment in these namespaces has all its replicas Ready."""
    good = True
    for namespace in namespaces:
        out = kubectl_out("get", "deployments", "-n", namespace, "-o",
                          r'jsonpath={range .items[*]}{.metadata.name} {.spec.replicas} {.status.readyReplicas}{"\n"}{end}')
        for line in out.splitlines():
            parts = line.split()
            if len(parts) < 2:
                continue
            want, have = parts[1], (parts[2] if len(parts) > 2 else "0")
            if have != want:
                good = False
                if not quiet:
                    warn("Deployment %s has %s of %s Pods Ready (namespace %s)." % (parts[0], have, want, namespace))
    return good


def need_helm():
    if shutil.which("helm") is None:
        die("This scenario uses Helm and it isn't installed. macOS: brew install helm · "
            "Windows: winget install Helm.Helm · Linux: https://helm.sh/docs/intro/install/")


def helm(*args):
    """Run helm quietly. Returns the exit code."""
    return subprocess.run(["helm", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode


# ------------------------------------------------------- cluster-level helpers --
def untaint_all(key):
    """Remove the taint KEY (any value, any effect) from every node. Silent and idempotent."""
    kubectl("taint", "nodes", "--all", key + "-")


def schedulable_node_count():
    """How many nodes accept new Pods: no NoSchedule/NoExecute taint and not cordoned. None on error."""
    out = kubectl_out("get", "nodes", "-o",
                      r'jsonpath={range .items[*]}{.metadata.name}{" U="}{.spec.unschedulable}{" "}'
                      r'{range .spec.taints[*]}{"|"}{.effect}{"|"}{end}{"\n"}{end}')
    lines = [line for line in out.splitlines() if line.strip()]
    if not lines:
        return None
    bad = [line for line in lines if " U=true " in line or "|NoSchedule|" in line or "|NoExecute|" in line]
    return len(lines) - len(bad)


def _metrics_available():
    return kubectl_out("get", "apiservice", "v1beta1.metrics.k8s.io", "-o",
                       'jsonpath={.status.conditions[?(@.type=="Available")].status}') == "True"


def ensure_metrics_server(label_id):
    """Make `kubectl top` work. Installs metrics-server only if the cluster has none. True when ready."""
    selector = "z2h.scenario=%s-installed" % label_id
    if _metrics_available():
        print("metrics-server already present")
        return True
    present = (kubectl_ok("get", "apiservice", "v1beta1.metrics.k8s.io")
               or kubectl_ok("get", "deployment", "metrics-server", "-n", "kube-system"))
    ours = bool(kubectl_out("get", "apiservice,deployment", "-A", "-l", selector, "-o", "name"))
    if present and not ours:
        print("metrics-server already present (not installed by us), waiting for it to become ready")
    else:
        with open(os.path.join(LIB_DIR, "_addons", "metrics-server.yaml"), encoding="utf-8") as f:
            manifest = f.read().replace("k25-installed", "%s-installed" % label_id)
        handle, path = tempfile.mkstemp(suffix=".yaml", prefix="z2h-ms-")
        try:
            with os.fdopen(handle, "w", encoding="utf-8") as f:
                f.write(manifest)
            if kubectl("apply", "-f", path)[0] != 0:
                return False
        finally:
            os.remove(path)
    limit = int(os.environ.get("Z2H_MS_WAIT", "180"))
    waited = 0
    while waited < limit:
        if kubectl_ok("top", "nodes"):
            return True
        time.sleep(2)
        waited += 2
    warn("metrics-server did not become ready within %ss. Check: kubectl -n kube-system get pods -l k8s-app=metrics-server" % limit)
    return False


def remove_metrics_server_if_ours(label_id):
    """Delete only the objects this scenario installed (a metrics-server that was already there stays)."""
    selector = "z2h.scenario=%s-installed" % label_id
    kubectl("delete", "apiservice", "-l", selector, "--ignore-not-found")
    kubectl("delete", "deployment,service,serviceaccount,rolebinding", "-n", "kube-system",
            "-l", selector, "--ignore-not-found")
    kubectl("delete", "clusterrolebinding,clusterrole", "-l", selector, "--ignore-not-found")
