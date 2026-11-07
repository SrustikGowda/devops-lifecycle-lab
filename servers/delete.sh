#!/usr/bin/env bash
# Delete the two lab servers and their disks. Use -y to skip the question.
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
require_lima

if [[ "${1:-}" != "-y" ]]; then
  read -r -p "Delete ${VMS[*]} and everything on them? [y/N] " answer || answer=""
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Nothing deleted."; exit 0; }
fi

for vm in "${VMS[@]}"; do
  if [[ -n "$(vm_status "$vm")" ]]; then
    echo "==> Deleting $vm"
    limactl delete --force "$vm"
  else
    echo "==> $vm does not exist"
  fi
done
