#!/usr/bin/env python3
"""S4.3 fix: re-create the disk request (PVC) without storageClassName, so the cluster's default StorageClass is used.

Run it from this folder:  python3 run.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
import scenario_lib as z  # noqa: E402

NS = "k-10-pvc-pending"


def pvc_bound():
    return z.kubectl_out("get", "pvc", "board-data", "-n", NS, "-o", "jsonpath={.status.phase}") == "Bound"


z.need_cluster()
z.say("Removing the stuck disk request and re-creating it without storageClassName…")
# A PVC's storageClassName is immutable: "kubectl apply" on the existing PVC would be rejected.
# So we delete it and create it again. Order matters: a PVC that a Pod still uses is protected
# from deletion (it would hang in Terminating), so the Deployment (and its Pending Pod) goes first.
if z.kubectl("delete", "deployment", "board", "-n", NS, "--ignore-not-found", "--wait=true")[0] != 0:
    z.die("Could not delete the Deployment.")
if z.kubectl("delete", "pvc", "board-data", "-n", NS, "--ignore-not-found", "--wait=true")[0] != 0:
    z.die("Could not delete the PVC.")
z.apply_dir(HERE)
z.must_wait("the Kanboard Deployment to be Ready", 180, lambda: z.rolled_out(NS, "board"),
            "The Pod didn't become Ready. Check: kubectl get pods,pvc -n " + NS)
z.must_wait("the disk (PVC) to be Bound", 60, pvc_bound,
            "The PVC isn't Bound. Check: kubectl get pvc -n " + NS)
z.show_next("✅ Fixed. Now verify it yourself:",
            "kubectl get pods,pvc -n " + NS,
            z.forward_hint(NS, "board", 9210))
