#!/usr/bin/env bash
# The whole pipeline in plain bash, on your laptop, no GitHub needed.
# It does what .github/workflows/ci.yml and pipeline.yml do, step by step, so you can see each stage on its own.
#
#   bash scripts/local-pipeline.sh
#
# Needs: Docker running, the venv (.venv with requirements-dev.txt), SonarQube up
# (docker compose -f sonarqube/compose.yml up -d), the servers up (bash servers/up.sh) and the local registry
# (bash servers/dev-registry.sh). Set SKIP_SONAR=1 to skip the quality gate, YES=1 to approve production automatically.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

version="$(cat VERSION)"
commit="$(git rev-parse HEAD 2>/dev/null || echo local)"
[ -z "$(git status --porcelain 2>/dev/null)" ] || commit="${commit:0:7}-dirty"
image="localhost:5001/devops-lifecycle-lab:${commit}"
server_image="host.lima.internal:5001/devops-lifecycle-lab:${commit}"   # same image, as the servers see it

# shellcheck disable=SC1091
source .venv/bin/activate

step "1/6 Lint"
ruff check .

step "2/6 Unit tests"
pytest

if [ "${SKIP_SONAR:-}" != "1" ]; then
  step "3/6 Quality gate (SonarQube)"
  SONAR_TOKEN="$(bash sonarqube/setup.sh)"
  export SONAR_TOKEN
  bash sonarqube/scan.sh
else
  step "3/6 Quality gate skipped (SKIP_SONAR=1)"
fi

step "4/6 Build the image and push it to the local registry"
docker build -q --build-arg APP_VERSION="$version" --build-arg GIT_SHA="$commit" -t "$image" .
docker push -q "$image"

export LAB_INSECURE_REGISTRY=host.lima.internal:5001

step "5/6 Deploy to staging"
bash runner/deploy.sh staging "$server_image" "$version"
curl -fsS http://localhost:8081/version; echo

step "6/6 Deploy to production"
if [ "${YES:-}" != "1" ]; then
  read -r -p "Staging is on $version. Approve production? [y/N] " answer
  [ "$answer" = "y" ] || { echo "Not approved. Production is unchanged."; exit 0; }
fi
bash runner/deploy.sh production "$server_image" "$version"
curl -fsS http://localhost:8082/version; echo
