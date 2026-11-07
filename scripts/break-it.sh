#!/usr/bin/env bash
# Make one deliberate, realistic mistake so you can watch the pipeline catch it.
# Usage: scripts/break-it.sh <test|coverage|port>
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
    echo "Changed 'ENV PORT=8080' to 'ENV PORT=9090' in Dockerfile: tests pass and the image builds, but nothing answers on 8080. Undo: git checkout -- ."
    ;;
  *)
    echo "Usage: $0 <test|coverage|port>" >&2
    exit 2
    ;;
esac
