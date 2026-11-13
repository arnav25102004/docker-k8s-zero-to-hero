#!/usr/bin/env python3
"""S1.x2 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-18-anti-affinity"
PORT = 9218


def nodes_settled():
    # A just-created cluster has nodes that are still starting (they carry a node.kubernetes.io/ taint
    # until they are Ready). Wait until none does, then read the count once.
    taints = z.kubectl_out("get", "nodes", "-o",
                           r'jsonpath={range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}')
    if any(t.startswith("node.kubernetes.io/") for t in taints.splitlines()):
        return False
    return (z.schedulable_node_count() or 0) >= 1


def one_waiting(replicas):
    # The intended state: all but one Pod are Running, one is still waiting, and the scheduler wrote an event.
    pods = z.kubectl_out("get", "pods", "-n", NS, "-l", "app=whoami", "--no-headers")
    return (pods.count(" Pending ") == 1 and pods.count(" Running ") == replicas - 1
            and z.events_contain(NS, "FailedScheduling"))


z.need_cluster()
z.run_cleanup(SCENARIO)
if not z.port_free(PORT):
    z.die("Port %s is busy, so this scenario can't start. Free it (see above) and run break again." % PORT)
if z.taint_left_over():
    z.die("The nodes still carry the z2h-vip taint from S2.3. Run its cleanup first, or: kubectl taint nodes --all z2h-vip-")
# Replicas = nodes that accept new Pods + 1 (kind: 3 nodes, control-plane tainted -> 2 -> 3 replicas).
z.wait_for("the nodes to be ready", 60, nodes_settled)
nodes = z.schedulable_node_count()
if nodes is None or nodes < 1:
    z.warn("Node status right now:")
    z.kubectl_show("get", "nodes", "-o", "custom-columns=NAME:.metadata.name,TAINTS:.spec.taints[*].key,UNSCHEDULABLE:.spec.unschedulable")
    z.die("No node accepts new Pods right now (all tainted or cordoned, or the cluster did not answer). "
          "Check: kubectl get nodes. If you just ran S2.3, run its cleanup first.")
replicas = nodes + 1
if not z.fresh_ns(NS):
    z.die("Could not create the namespace %s." % NS)
z.say("Scaling whoami for the open-house traffic (%d Pods)…" % replicas)
if z.kubectl("create", "configmap", "visitor-config", "-n", NS, "--from-literal=want=%d" % replicas)[0] != 0:
    z.die("Could not create the visitor settings.")
z.apply_dir(HERE)
if z.kubectl("scale", "deployment/whoami", "-n", NS, "--replicas=%d" % replicas)[0] != 0:
    z.die("Could not scale whoami.")
z.wait_visitor(NS)
z.must_wait("whoami to finish scaling", 180, lambda: one_waiting(replicas),
            "The Pods never settled as expected. Run cleanup.py and try again.")
z.scene_set()
