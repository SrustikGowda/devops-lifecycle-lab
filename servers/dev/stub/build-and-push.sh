#!/usr/bin/env bash
# Build the stub image twice and push it to the local test registry (start it first: bash servers/dev-registry.sh).
#   localhost:5001/lab-stub:good  listens on 8080 -> healthy
#   localhost:5001/lab-stub:bad   listens on 9090 -> /health fails, so the deploy rolls back
# The VMs pull the same images as host.lima.internal:5001/lab-stub:<tag>.
set -euo pipefail
cd "$(dirname "$0")"

docker build -q --build-arg PORT=8080 -t localhost:5001/lab-stub:good .
docker build -q --build-arg PORT=9090 -t localhost:5001/lab-stub:bad .
docker push -q localhost:5001/lab-stub:good
docker push -q localhost:5001/lab-stub:bad
echo "Pushed localhost:5001/lab-stub:good and :bad"
