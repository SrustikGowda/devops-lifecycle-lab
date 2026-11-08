#!/usr/bin/env bash
# Make one deliberate, realistic mistake so you can watch the pipeline catch it.
# Usage: scripts/break-it.sh <test|coverage|port|k8s-port|k8s-memory>
# Undo:  git checkout -- .
set -eu

cd "$(dirname "$0")/.."

# Replace $2 with $3 in file $1. Works with BSD sed (macOS) and GNU sed (Linux): no -i.
replace() {
  sed "s/$2/$3/" "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

case "${1:-}" in
  test)
    # Flip a comparison: fast answers become DELAYED, so the unit tests fail.
    if grep -q 'elapsed < SLOW_SECONDS' app/board.py; then
      echo "Already broken. Undo: git checkout -- ."
      exit 0
    fi
    grep -q 'elapsed > SLOW_SECONDS' app/board.py || { echo "app/board.py has changed, nothing to break." >&2; exit 1; }
    replace app/board.py 'elapsed > SLOW_SECONDS' 'elapsed < SLOW_SECONDS'
    echo "Broke app/board.py: 'elapsed > SLOW_SECONDS' became 'elapsed < SLOW_SECONDS', so fast sites show DELAYED. Tests will fail. Undo: git checkout -- ."
    ;;
  coverage)
    # Add a plausible function that no test calls: tests still pass, coverage drops.
    if grep -q 'def summarize' app/board.py; then
      echo "Already broken. Undo: git checkout -- ."
      exit 0
    fi
    cat >> app/board.py <<'PY'


def summarize(rows):
    """Count how many sites are in each state and say whether the board is healthy."""
    counts = {ON_TIME: 0, DELAYED: 0, PROBLEM: 0}
    for row in rows:
        counts[row["status"]] += 1
    if counts[PROBLEM] > 0:
        headline = f"{counts[PROBLEM]} site(s) down"
    elif counts[DELAYED] > 0:
        headline = f"{counts[DELAYED]} site(s) slow"
    else:
        headline = "all sites on time"
    total = sum(counts.values())
    healthy = counts[ON_TIME] == total
    percent = round(100 * counts[ON_TIME] / total) if total else 0
    return {"counts": counts, "headline": headline, "healthy": healthy, "percent": percent}
PY
    echo "Added an untested summarize() to app/board.py: all tests pass, but coverage drops below 80%. Undo: git checkout -- ."
    ;;
  port)
    # The app now listens on 9090, but the deploy still maps and checks port 8080.
    if grep -q '^ENV PORT=9090$' Dockerfile; then
      echo "Already broken. Undo: git checkout -- ."
      exit 0
    fi
    grep -q '^ENV PORT=8080$' Dockerfile || { echo "Dockerfile has changed, nothing to break." >&2; exit 1; }
    replace Dockerfile '^ENV PORT=8080$' 'ENV PORT=9090'
    echo "Changed 'ENV PORT=8080' to 'ENV PORT=9090' in Dockerfile: tests pass, but nothing answers on 8080: the CI smoke test fails, and a deploy rolls back. Undo: git checkout -- ."
    ;;
  k8s-port)
    # Episode 5: the same port mistake, one layer down, in the Kubernetes file. CI never reads k8s/, so every
    # check passes; only the cluster can catch it (the readiness probe still asks port 8080).
    if grep -q 'value: "9090"' k8s/base/deployment.yaml; then
      echo "Already broken. Undo: git checkout -- ."
      exit 0
    fi
    [ "$(grep -c 'value: "8080"' k8s/base/deployment.yaml)" = 1 ] ||
      { echo "k8s/base/deployment.yaml has changed, nothing to break." >&2; exit 1; }
    replace k8s/base/deployment.yaml 'value: "8080"' 'value: "9090"'
    echo "Changed PORT from \"8080\" to \"9090\" in k8s/base/deployment.yaml: CI passes, but the new pods never become ready, so the rollout stops and the old pods keep serving. Undo: git checkout -- . (or kubectl rollout undo on the cluster)"
    ;;
  k8s-memory)
    # Episode 5: a memory limit far below what the app uses (about 74 MiB): the new pods are OOMKilled.
    if grep -q 'memory: 32Mi' k8s/base/deployment.yaml; then
      echo "Already broken. Undo: git checkout -- ."
      exit 0
    fi
    if ! { grep -q 'memory: 96Mi' k8s/base/deployment.yaml && grep -q 'memory: 192Mi' k8s/base/deployment.yaml; }; then
      echo "k8s/base/deployment.yaml has changed, nothing to break." >&2
      exit 1
    fi
    replace k8s/base/deployment.yaml 'memory: 96Mi' 'memory: 32Mi'
    replace k8s/base/deployment.yaml 'memory: 192Mi' 'memory: 32Mi'
    echo "Set the memory request and limit to 32Mi in k8s/base/deployment.yaml: the new pods are OOMKilled (exit code 137) and restart again and again, so the rollout stops and the old pods keep serving. Undo: git checkout -- . (or kubectl rollout undo on the cluster)"
    ;;
  *)
    echo "Usage: $0 <test|coverage|port|k8s-port|k8s-memory>" >&2
    exit 2
    ;;
esac
