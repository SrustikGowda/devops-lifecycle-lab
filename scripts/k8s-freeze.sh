#!/usr/bin/env bash
# Freeze the app inside one pod, the way a deadlock would: the processes are still there, but nothing answers.
#
#   bash scripts/k8s-freeze.sh [namespace]          (default: staging)
#
# Watch it in another terminal:  kubectl --context kind-lab -n staging get pods -w
# What you should see: first READY goes 1/1 -> 0/1 (the readiness probe fails, so the Service stops sending it
# requests), then RESTARTS goes up by one (the liveness probe fails, so the container is restarted), then 1/1 again.
#
# It stops gunicorn's worker processes. gunicorn's main process is PID 1 in the container, and PID 1 can't be
# stopped from inside it, so it stays up, but with its workers frozen, nothing answers requests.
set -euo pipefail
ns="${1:-staging}"
kc() { kubectl --context kind-lab -n "$ns" "$@"; }

pod="$(kc get pods -l app=status-board --field-selector=status.phase=Running \
        -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].ready}{"\n"}{end}' |
      awk '$2 == "true" { print $1; exit }')"
[ -n "$pod" ] || { echo "No ready status-board pod in namespace $ns." >&2; exit 1; }

echo "Freezing the app in $pod ($ns)"
kc exec "$pod" -- python -c '
import os, signal
me = os.getpid()
for pid in (int(p) for p in os.listdir("/proc") if p.isdigit()):
    if pid in (1, me):
        continue
    try:
        cmdline = open(f"/proc/{pid}/cmdline", "rb").read()
    except OSError:
        continue
    if b"gunicorn" in cmdline:
        os.kill(pid, signal.SIGSTOP)
        print("  stopped worker", pid)
'
