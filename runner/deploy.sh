#!/usr/bin/env bash
# Deploy one image to staging or production with Ansible.
# The pipeline's deploy jobs call this on your self-hosted runner; you can run it by hand too.
#
#   bash runner/deploy.sh <staging|production> <image> <version>
#
# First run: creates a Python venv with Ansible in ~/.cache/devops-lifecycle-lab (about a minute), reused afterwards.
# Local testing only: LAB_INSECURE_REGISTRY=host.lima.internal:5001 lets the servers pull from the local test registry.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -ne 3 ]; then
  echo "Usage: bash runner/deploy.sh <staging|production> <image> <version>" >&2
  exit 2
fi
target="$1" image="$2" version="$3"
case "$target" in staging|production) ;; *) echo "Target must be staging or production" >&2; exit 2 ;; esac

# Find Python 3.12 or newer (the runner service may not have Homebrew on its PATH).
PY="${PYTHON:-}"
for candidate in python3.13 python3.12 python3 \
                 /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12; do
  [ -n "$PY" ] && break
  if command -v "$candidate" >/dev/null 2>&1 &&
     "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 12))' 2>/dev/null; then
    PY="$candidate"
  fi
done
[ -n "$PY" ] || { echo "Python 3.12+ not found. macOS: brew install python@3.12; Ubuntu: apt install python3" >&2; exit 1; }

# One Ansible install per set of requirements, kept between runs.
VENV="${LAB_ANSIBLE_VENV:-$HOME/.cache/devops-lifecycle-lab/ansible-venv}"
if command -v sha256sum >/dev/null 2>&1; then hash_cmd=(sha256sum); else hash_cmd=(shasum -a 256); fi
stamp="$(cat ansible/requirements-deploy.txt ansible/requirements.yml | "${hash_cmd[@]}" | cut -c1-12)"
if [ ! -f "$VENV/.ready-$stamp" ]; then
  echo "Setting up Ansible in $VENV (first run only)..."
  rm -rf "$VENV"
  "$PY" -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check -r ansible/requirements-deploy.txt
  "$VENV/bin/ansible-galaxy" collection install -r ansible/requirements.yml -p "$VENV/collections" >/dev/null
  touch "$VENV/.ready-$stamp"
fi

export ANSIBLE_CONFIG=ansible/ansible.cfg
export ANSIBLE_COLLECTIONS_PATH="$VENV/collections"
export ANSIBLE_FORCE_COLOR=1

extra=()
if [ -n "${LAB_INSECURE_REGISTRY:-}" ]; then
  extra=(-e "{\"insecure_registries\": [\"$LAB_INSECURE_REGISTRY\"]}")
fi

echo "Deploying $image ($version) to $target"
"$VENV/bin/ansible-playbook" ansible/deploy.yml -l "$target" \
  -e "app_image=$image" -e "app_version=$version" ${extra[@]+"${extra[@]}"}
