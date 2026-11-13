#!/usr/bin/env python3
"""S3.3 break: sets up the scene. Working out what is wrong is the exercise; start with the README.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

SCENARIO = os.path.dirname(HERE)

APP = "k-12-dns-app"
DATA = "k-12-dns-data"


def redis_ready():
    return z.kubectl_out("get", "pod", "-n", DATA, "-l", "app=redis", "-o",
                         "jsonpath={.items[0].status.containerStatuses[0].ready}") == "true"


def app_cannot_find_redis():
    # The intended failure: the app is up and running, but cannot find Redis (readiness answers 503).
    phase = z.kubectl_out("get", "pod", "-n", APP, "-l", "app=showdown", "-o", "jsonpath={.items[0].status.phase}")
    if "Running" not in phase:
        return False
    if not z.logs_contain(APP, "listening on", "-l", "app=showdown"):
        return False
    return z.logs_contain(APP, "not ready", "visitor")


z.need_cluster()
z.run_cleanup(SCENARIO)
if not z.port_free(9212):
    z.die("Port 9212 is busy, so this scenario can't start. Free it (see above) and run break again.")
if not z.fresh_ns(APP, DATA):
    z.die("Could not create the namespaces %s and %s." % (APP, DATA))
if not z.create_showdown_configmap(APP):
    z.die("Could not create the ConfigMap showdown-code.")
z.say("Deploying Redis (in %s), the Cats vs Dogs app and a visitor (in %s)…" % (DATA, APP))
z.apply_dir(HERE)
z.must_wait("Redis to start (the first download can take a minute)", 180, redis_ready,
            "Redis didn't start. Run cleanup.py and try again.")
z.wait_visitor(APP)
z.must_wait("the app to start and fail to find Redis", 180, app_cannot_find_redis,
            "Expected the app to be up but not ready, and it isn't. Run cleanup.py and try again.")
z.scene_set()
