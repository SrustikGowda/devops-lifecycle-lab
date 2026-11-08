#!/usr/bin/env bash
# Episode 5, laptop only: staging and production on a local Kubernetes cluster. No GitHub needed.
#
#   bash scripts/k8s-up.sh
#
# 1. Creates the kind cluster "lab" (k8s/kind-config.yaml) if it isn't there yet.
# 2. Builds the app as status-board:local-<commit> (a new name for every build, so a rebuild really rolls out).
# 3. Copies that image into the cluster's nodes (they can't see your laptop's Docker images otherwise).
# 4. Deploys it to staging (http://localhost:8081) and production (http://localhost:8082).
# Remove everything with: bash scripts/k8s-down.sh
set -euo pipefail
cd "$(dirname "$0")/.."

for tool in docker kind kubectl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool not found. See docs/09-kubernetes.md, 'What you need'." >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker Desktop (or Colima) first." >&2; exit 1; }

clusters="$(kind get clusters 2>/dev/null || true)"
if grep -qx lab <<<"$clusters"; then
  echo "Cluster \"lab\" already exists."
else
  # Episode 4's Lima servers use the same two ports. Stop them first: bash servers/down.sh
  for port in 8081 8082; do
    if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "Port $port is in use (episode 4's servers? run: bash servers/down.sh), so the cluster can't use it." >&2
      exit 1
    fi
  done
  kind create cluster --config k8s/kind-config.yaml
fi
kubectl --context kind-lab wait --for=condition=Ready node --all --timeout=120s >/dev/null

commit="$(git rev-parse HEAD 2>/dev/null || echo local)"
name="local-${commit:0:7}"
# Uncommitted or new files? Add the time, so the new build gets its own name and Kubernetes rolls it out.
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then name="$name-$(date +%H%M%S)"; fi
image="status-board:$name"
version="$(cat VERSION)"

echo "Building $image (version $version)"
# BuildKit can attach extra data (provenance) that `kind load` may fail to copy, so leave it out.
# The older builder (some Colima setups) has no such flag and adds no such data.
extra=()
if docker buildx version >/dev/null 2>&1; then extra=(--provenance=false); fi
docker build -q ${extra[@]+"${extra[@]}"} --build-arg APP_VERSION="$version" --build-arg GIT_SHA="$commit" \
  -t "$image" . >/dev/null
echo "Copying $image into the cluster's nodes"
kind load docker-image "$image" --name lab

bash runner/deploy-k8s.sh staging "$image" "$version"
bash runner/deploy-k8s.sh production "$image" "$version"
echo
echo "Staging:    http://localhost:8081"
echo "Production: http://localhost:8082"
