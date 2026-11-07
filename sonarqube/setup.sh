#!/usr/bin/env bash
# Prepare a fresh SonarQube for this lab and print an analysis token on the last line.
#   - waits until SonarQube is up
#   - creates the quality gate "lab-gate": FAIL if overall test coverage is below 80%
#   - makes it the default gate
#   - prints a token the scanner can use
# Usage:  export SONAR_TOKEN=$(bash sonarqube/setup.sh)
# Env:    SONAR_HOST_URL (default http://localhost:9000), SONAR_ADMIN (default admin:admin)
#
# Why a custom gate? SonarQube's built-in "Sonar way" gate only judges *new* code, and on the very first analysis of a
# project there is no new code yet, so it always passes. Our gate judges the whole project, so a drop in coverage fails.
set -euo pipefail

HOST="${SONAR_HOST_URL:-http://localhost:9000}"
ADMIN="${SONAR_ADMIN:-admin:admin}"
GATE="lab-gate"
MIN_COVERAGE="${MIN_COVERAGE:-80}"

api() { curl -fsS -u "$ADMIN" "$@"; }
log() { echo "$*" >&2; }

log "Waiting for SonarQube at $HOST ..."
for _ in $(seq 1 60); do
  if curl -fsS "$HOST/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then break; fi
  sleep 5
done
curl -fsS "$HOST/api/system/status" | grep -q '"status":"UP"' || { log "SonarQube did not come up"; exit 1; }
log "SonarQube is up."

if ! api "$HOST/api/authentication/validate" | grep -q '"valid":true'; then
  log "SonarQube rejected the login ${ADMIN%%:*}. If you changed the admin password in the web page, run:"
  log "  export SONAR_ADMIN='admin:<your new password>'"
  exit 1
fi

if ! api "$HOST/api/qualitygates/list" | grep -q "\"name\":\"$GATE\""; then
  api -X POST "$HOST/api/qualitygates/create" --data-urlencode "name=$GATE" >/dev/null
  # New gates come with SonarQube's default "new code" conditions; keep this gate to one rule you can see and test.
  for id in $(api "$HOST/api/qualitygates/show?name=$GATE" \
                | python3 -c 'import json,sys; print(" ".join(c["id"] for c in json.load(sys.stdin)["conditions"]))'); do
    api -X POST "$HOST/api/qualitygates/delete_condition" --data-urlencode "id=$id" >/dev/null
  done
  api -X POST "$HOST/api/qualitygates/create_condition" \
    --data-urlencode "gateName=$GATE" --data-urlencode "metric=coverage" \
    --data-urlencode "op=LT" --data-urlencode "error=$MIN_COVERAGE" >/dev/null
  log "Created quality gate $GATE: fail when coverage < $MIN_COVERAGE%."
else
  log "Quality gate $GATE already exists."
fi
api -X POST "$HOST/api/qualitygates/set_as_default" --data-urlencode "name=$GATE" >/dev/null

TOKEN_NAME="lab-$(date +%s)"
api -X POST "$HOST/api/user_tokens/generate" \
  --data-urlencode "name=$TOKEN_NAME" --data-urlencode "type=GLOBAL_ANALYSIS_TOKEN" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])'
