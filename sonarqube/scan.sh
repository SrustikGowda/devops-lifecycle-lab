#!/usr/bin/env bash
# Run the SonarQube scanner (in Docker) on this repo and wait for the quality gate.
# Needs: coverage.xml at the repo root (run `pytest` first) and SONAR_TOKEN (from sonarqube/setup.sh).
# Exit code is non-zero when the quality gate fails, so a pipeline stops right here.
set -euo pipefail

: "${SONAR_TOKEN:?Set SONAR_TOKEN first: export SONAR_TOKEN=\$(bash sonarqube/setup.sh)}"
[ -f coverage.xml ] || { echo "coverage.xml not found: run pytest first" >&2; exit 1; }

if docker info --format '{{.OperatingSystem}}' 2>/dev/null | grep -q "Docker Desktop"; then
  # Docker Desktop (macOS, Windows, or Linux): containers reach your machine at host.docker.internal.
  NET=(); HOST="${SONAR_HOST_URL:-http://host.docker.internal:9000}"
else
  # Docker Engine on Linux (like a CI runner): SonarQube is on localhost, so share the host's network.
  NET=(--network host); HOST="${SONAR_HOST_URL:-http://localhost:9000}"
fi

# ${NET[@]+...}: an empty array is fine even with `set -u` on macOS's older bash.
docker run --rm ${NET[@]+"${NET[@]}"} \
  -e SONAR_HOST_URL="$HOST" -e SONAR_TOKEN="$SONAR_TOKEN" \
  -v "$PWD:/usr/src" \
  sonarsource/sonar-scanner-cli:11.5 \
  -Dsonar.scm.disabled=true
