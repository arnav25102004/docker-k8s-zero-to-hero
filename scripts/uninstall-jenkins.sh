#!/usr/bin/env bash
# Remove Jenkins (installed by install-jenkins.sh), the showdown namespace and the deployer permissions.
set -u
command -v helm >/dev/null 2>&1 && helm uninstall jenkins -n jenkins >/dev/null 2>&1 && echo "✔ Jenkins release removed" || echo "(no Jenkins release found)"
kubectl delete namespace jenkins showdown --ignore-not-found --wait=false >/dev/null 2>&1
echo "✔ namespaces jenkins and showdown removed (the mail catcher and monitoring stay)"
