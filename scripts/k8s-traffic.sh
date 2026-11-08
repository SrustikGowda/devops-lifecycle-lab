#!/usr/bin/env bash
# A stand-in for users: ask the app for /version five times a second and keep score.
#
#   bash scripts/k8s-traffic.sh [port] [log file]
#
# port: 8082 = production (the default), 8081 = staging.
# A request counts as failed if it doesn't answer 200 within 1 second. Every request opens a new connection,
# so the Service can send each one to a different pod. Stop with Ctrl-C to see how many requests each pod answered.
# Each request is also written to the log file (default: $TMPDIR/k8s-traffic-<port>.log) with a timestamp.
set -euo pipefail
port="${1:-8082}"
log="${2:-${TMPDIR:-/tmp}/k8s-traffic-$port.log}"
exec python3 - "$port" "$log" <<'PY'
import json
import signal
import sys
import time
import urllib.request
from collections import Counter


def stop(*_):
    raise KeyboardInterrupt


# Stop cleanly on Ctrl-C, and on `kill` (a script that starts this in the background can't send Ctrl-C).
signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)

port, log_path = sys.argv[1], sys.argv[2]
url = f"http://localhost:{port}/version"
ok = failed = 0
by_pod = Counter()
green, red, dim, reset = "\033[32m", "\033[31m", "\033[2m", "\033[0m"

with open(log_path, "w", buffering=1) as log:
    try:
        while True:
            started = time.time()
            pod = "-"
            try:
                with urllib.request.urlopen(url, timeout=1) as reply:
                    body = json.loads(reply.read() or b"{}")
                    pod = body.get("pod") or "-"
                    good = reply.status == 200
            except Exception:
                good = False
            if good:
                ok += 1
                by_pod[pod] += 1
            else:
                failed += 1
            took = time.time() - started
            log.write(f"{started:.3f} {'ok' if good else 'FAILED'} {took * 1000:.0f}ms {pod}\n")
            colour = red if failed else green
            sys.stdout.write(
                f"\r{green}✓ {ok:,} ok{reset}   {colour}✗ {failed:,} failed{reset}   "
                f"{dim}last: {pod if good else 'no answer'}{reset}\033[K"
            )
            sys.stdout.flush()
            time.sleep(max(0.0, 0.2 - took))
    except KeyboardInterrupt:
        print(f"\n\n{ok:,} ok, {failed:,} failed. Answered by:")
        for name, count in by_pod.most_common():
            print(f"  {name}  {count:,}")
        print(f"Log: {log_path}")
PY
