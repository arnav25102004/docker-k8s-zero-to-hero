#!/usr/bin/env python3
"""S3.5 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-13-lockdown"
PROBE = "k-13-probe"

PROBE_PODS = """\
apiVersion: v1
kind: Pod
metadata:
  name: target
  labels: {app: target}
spec:
  terminationGracePeriodSeconds: 1
  containers:
    - name: target
      image: busybox:1.36
      command: ["sh", "-c", "mkdir -p /www && echo ok > /www/index.html && httpd -f -p 80 -h /www"]
---
apiVersion: v1
kind: Service
metadata:
  name: target
spec:
  selector: {app: target}
  ports: [{port: 80}]
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  labels: {app: client}
spec:
  terminationGracePeriodSeconds: 1
  containers:
    - name: client
      image: busybox:1.36
      command: ["sleep", "3600"]
"""

DENY_ALL_EGRESS = """\
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector:
    matchLabels: {app: client}
  policyTypes: [Egress]
"""


def redis_ready():
    return z.kubectl_out("get", "pod", "-n", NS, "-l", "app=redis", "-o",
                         "jsonpath={.items[0].status.containerStatuses[0].ready}") == "true"


def app_cannot_resolve():
    # The intended failure: the app is up, but its visitor sees "not ready" and the log shows the failed lookup.
    phase = z.kubectl_out("get", "pod", "-n", NS, "-l", "app=showdown", "-o", "jsonpath={.items[0].status.phase}")
    if "Running" not in phase:
        return False
    if not z.logs_contain(NS, "not ready", "visitor"):
        return False
    return z.logs_contain(NS, "readiness failed", "-l", "app=showdown", "--tail=50")


def probe_enforces():
    """Does this cluster really enforce NetworkPolicy? Some don't (often Docker Desktop or a default minikube):
    there a policy is accepted and silently ignored, and this scenario would show nothing.
    Test: a client reaches a target Service; then a deny-all-egress policy goes on the client;
    if the client can STILL reach the target, nothing is enforcing policies.
    Returns True (enforced), False (not enforced) or None (the check could not finish)."""
    if not z.fresh_ns(PROBE):
        return None
    if z.kubectl("apply", "-n", PROBE, "-f", "-", input_text=PROBE_PODS)[0] != 0:
        return None
    if not z.wait_for("the probe Pods to start", 120, lambda: z.pod_phase(PROBE, "target") == "Running"):
        return None
    if not z.wait_for("the probe client to start", 120, lambda: z.pod_phase(PROBE, "client") == "Running"):
        return None
    ip = z.kubectl_out("get", "svc", "target", "-n", PROBE, "-o", "jsonpath={.spec.clusterIP}")
    # Baseline: before any policy the client must reach the target (by IP, so DNS is not involved).
    for _ in range(10):
        if z.kubectl_ok("exec", "-n", PROBE, "client", "--", "wget", "-q", "-T", "2", "-O", "/dev/null", "http://%s/" % ip):
            break
        time.sleep(1)
    else:
        return None
    if z.kubectl("apply", "-n", PROBE, "-f", "-", input_text=DENY_ALL_EGRESS)[0] != 0:
        return None
    # Enforcement can take a moment to arrive: try up to 8 times. Only 2 failures in a row count
    # as "enforced" (one odd exec error must not pass for a blocked connection).
    fails = 0
    for _ in range(8):
        if z.kubectl_ok("exec", "-n", PROBE, "client", "--", "wget", "-q", "-T", "1", "-O", "/dev/null", "http://%s/" % ip):
            fails = 0
        else:
            fails += 1
        if fails >= 2:
            return True
        time.sleep(1)
    return False


z.need_cluster()
z.run_cleanup(SCENARIO)
if not z.port_free(9213):
    z.die("Port 9213 is busy, so this scenario can't start. Free it (see above) and run break again.")
z.say("Checking that this cluster enforces NetworkPolicy (a quick check, about 15 seconds)…")
enforced = probe_enforces()
z.delete_ns(PROBE)
if enforced is False:
    z.die("This cluster doesn't enforce NetworkPolicy (e.g. Docker Desktop, default minikube). "
          "Use kind, Killercoda or iximiuz for this scenario.")
if enforced is None:
    z.die("The NetworkPolicy check couldn't finish. Run cleanup.py and try again.")
z.ok("NetworkPolicy is enforced here.")
if not z.fresh_ns(NS):
    z.die("Could not create the namespace %s." % NS)
if not z.create_showdown_configmap(NS):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Deploying Redis, the Cats vs Dogs app, a visitor and the lockdown policy…")
z.apply_dir(HERE)
z.must_wait("Redis to start (the first download can take a minute)", 180, redis_ready,
            "Redis didn't start. Run cleanup.py and try again.")
z.wait_visitor(NS)
z.must_wait("the app to start and fail to look up Redis", 180, app_cannot_resolve,
            "Expected the app to be up but not ready, and it isn't. Run cleanup.py and try again.")
z.scene_set()
