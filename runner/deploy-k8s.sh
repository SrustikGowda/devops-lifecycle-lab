#!/usr/bin/env bash
# Deploy one image to staging or production on the kind cluster, with kubectl.
# The pipeline's deploy jobs call this on your self-hosted runner; you can run it by hand too.
#
#   bash runner/deploy-k8s.sh <staging|production> <image> <version>
#
# It applies k8s/overlays/<target> with your image, writes the version into the rollout history, and waits for the
# rollout. If the new version never becomes ready, it shows what Kubernetes saw and exits 1. It does NOT undo it:
# the old pods are still serving users, and the stuck pod is the evidence you need. To undo:
#   kubectl --context kind-lab -n <target> rollout undo deployment/status-board
# (Want it automatic? Add that command just before the final "exit 1" below.)
set -euo pipefail
cd "$(dirname "$0")/.."

# Always this cluster, never whatever your kubeconfig happens to point at (a work cluster, say).
CONTEXT="kind-lab"
TIMEOUT="${LAB_ROLLOUT_TIMEOUT:-120s}"

if [ $# -ne 3 ]; then
  echo "Usage: bash runner/deploy-k8s.sh <staging|production> <image> <version>" >&2
  exit 2
fi
target="$1" image="$2" version="$3"
case "$target" in staging|production) ;; *) echo "Target must be staging or production" >&2; exit 2 ;; esac

# Find kubectl (the runner service may not have Homebrew or Docker Desktop on its PATH).
KUBECTL="${KUBECTL:-}"
for candidate in kubectl /opt/homebrew/bin/kubectl /usr/local/bin/kubectl "$HOME/.docker/bin/kubectl"; do
  [ -n "$KUBECTL" ] && break
  if command -v "$candidate" >/dev/null 2>&1; then KUBECTL="$(command -v "$candidate")"; fi
done
[ -n "$KUBECTL" ] || { echo "kubectl not found. macOS: brew install kubectl (Docker Desktop also ships one)" >&2; exit 1; }

if ! "$KUBECTL" config get-contexts "$CONTEXT" >/dev/null 2>&1; then
  echo "No kubectl context \"$CONTEXT\". Create the cluster first: kind create cluster --config k8s/kind-config.yaml" >&2
  exit 1
fi
# And that context must be a cluster on this laptop, as kind makes it.
server="$("$KUBECTL" config view --minify --context "$CONTEXT" -o jsonpath='{.clusters[0].cluster.server}')"
case "$server" in
  https://127.0.0.1:*|https://localhost:*) ;;
  *) echo "Context $CONTEXT points at $server, not a cluster on this laptop. Refusing to deploy." >&2; exit 1 ;;
esac
k() { "$KUBECTL" --context "$CONTEXT" -n "$target" "$@"; }

# Short name for the rollout history: the first 7 characters of a commit tag, or the whole tag.
tag="${image##*:}"
if [[ "$tag" =~ ^[0-9a-f]{40}$ ]]; then short="${tag:0:7}"; else short="$tag"; fi

echo "Deploying $image ($version) to $target"
# Render this environment's files, and put the real image where the placeholder status-board:dev is.
rendered="$("$KUBECTL" kustomize "k8s/overlays/$target" | sed "s#image: status-board:dev#image: $image#")"
grep -q "image: $image" <<<"$rendered" || { echo "Could not put $image into the Deployment" >&2; exit 1; }
"$KUBECTL" --context "$CONTEXT" apply -f - <<<"$rendered"

# Write the version next to this revision, so `kubectl rollout history` shows 1.5.0, 1.5.1 ... instead of numbers only.
k annotate deployment/status-board --overwrite kubernetes.io/change-cause="$version ($short)" >/dev/null

if k rollout status deployment/status-board --timeout="$TIMEOUT"; then
  k get pods -l app=status-board -o wide
  echo "DEPLOYED $version to $target"
  exit 0
fi

echo
ready="$(k get deployment/status-board -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
if [ -n "$ready" ] && [ "$ready" != 0 ]; then
  echo "ROLLOUT STUCK: $version never became ready on $target. $ready pods of the previous version are still serving users."
else
  echo "ROLLOUT STUCK: $version never became ready on $target, and no ready pods are serving users."
fi
k get pods -l app=status-board -o wide || true
# A pod that is not ready: that's the one to look at.
stuck="$(k get pods -l app=status-board \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].ready}{"\n"}{end}' |
  awk '$2 != "true" { print $1; exit }')"
if [ -n "$stuck" ]; then
  echo
  echo "What Kubernetes saw (pod/$stuck):"
  k describe "pod/$stuck" | sed -n '/^Events:/,$p' | tail -n 12 || true
  echo
  echo "What the app said (last 20 lines):"
  logs="$(k logs "pod/$stuck" --tail=20 2>/dev/null || true)"
  # Nothing yet? The container may have just restarted: read the one before.
  [ -n "$logs" ] || logs="$(k logs "pod/$stuck" --previous --tail=20 2>/dev/null || true)"
  echo "${logs:-(nothing)}"
fi
echo
echo "Find the cause, then undo: kubectl --context $CONTEXT -n $target rollout undo deployment/status-board"
exit 1
