#!/usr/bin/env bash
# Delete the episode-5 cluster "lab" and everything in it (staging and production). Your images stay in Docker.
#   bash scripts/k8s-down.sh
set -euo pipefail
kind delete cluster --name lab
