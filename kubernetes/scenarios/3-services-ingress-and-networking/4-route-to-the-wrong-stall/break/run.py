#!/usr/bin/env python3
"""S3.4 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

NS = "k-33-gateway"


def proxy_svc():
    return z.kubectl_out("get", "svc", "-n", "envoy-gateway-system", "-l",
                         "gateway.envoyproxy.io/owning-gateway-name=stalls,gateway.envoyproxy.io/owning-gateway-namespace=" + NS,
                         "-o", "jsonpath={.items[0].metadata.name}")


def route_unresolved():
    return z.kubectl_out("get", "httproute", "menu", "-n", NS, "-o",
                         'jsonpath={.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}') == "False"


z.need_cluster()
if not z.kubectl_ok("get", "gatewayclass", "eg"):
    z.die("No Gateway controller found. This scenario routes traffic through Envoy Gateway. "
          "Install it once (about 2 minutes): ./scripts/install-gateway.sh")
z.run_cleanup(SCENARIO)
if not z.fresh_ns(NS):
    z.die("Could not create the namespace %s." % NS)
z.say("Opening two stalls and a front door (a Gateway) with a route to each…")
z.apply_files(os.path.join(HERE, "app.yaml"))
z.must_wait("the Gateway's proxy Service to appear (about a minute)", 240, lambda: proxy_svc() != "",
            "The Gateway's proxy never appeared. Check: kubectl get gateway -n %s   and   kubectl get pods -n envoy-gateway-system" % NS)
z.must_wait("the route to be evaluated", 120, route_unresolved,
            "The route was not evaluated as expected. Run cleanup.py and try again.")
url = "http://%s.envoy-gateway-system.svc.cluster.local" % proxy_svc()
with open(os.path.join(HERE, "visitor.yaml"), encoding="utf-8") as f:
    visitor = f.read().replace("@URL@", url)
if z.kubectl("apply", "-f", "-", input_text=visitor)[0] != 0:
    z.die("Could not start the visitor.")
z.wait_visitor(NS)
z.scene_set()
