#!/usr/bin/env bash
# Start a throwaway Docker registry on this Mac at localhost:5001 (container: lab-registry).
# For testing the deploy locally before the GitHub registry is used. The VMs reach it as
# host.lima.internal:5001 over plain HTTP, so deploys must pass:
#   -e '{"insecure_registries": ["host.lima.internal:5001"]}'
# Stop it:  docker rm -f lab-registry
set -euo pipefail

if [[ -n "$(docker ps -q --filter name='^lab-registry$')" ]]; then
  echo "lab-registry is already running on localhost:5001"
elif [[ -n "$(docker ps -aq --filter name='^lab-registry$')" ]]; then
  docker start lab-registry >/dev/null
  echo "Started lab-registry on localhost:5001"
else
  # Bound to 127.0.0.1 only: your Mac and its Lima VMs can use it, other machines on your network cannot.
  docker run -d --name lab-registry --restart unless-stopped -p 127.0.0.1:5001:5000 registry:2 >/dev/null
  echo "Started lab-registry on localhost:5001"
fi
