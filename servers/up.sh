#!/usr/bin/env bash
# Create (first time) and start the two lab servers: lab-staging and lab-prod.
# Safe to run again: a VM that is already running is left alone.
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
require_lima

# On a Mac, use Apple's own virtualization (fast). On Linux, use QEMU.
if [[ "$(uname -s)" == "Darwin" ]]; then VM_TYPE=vz; else VM_TYPE=qemu; fi

for vm in "${VMS[@]}"; do
  status="$(vm_status "$vm")"
  case "$status" in
    Running)
      echo "==> $vm is already running"
      ;;
    Stopped)
      echo "==> Starting $vm"
      limactl start --tty=false "$vm"
      ;;
    "")
      port="$(app_port_of "$vm")"
      if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "WARNING: something on this Mac already listens on port $port; $vm's app will not be reachable there." >&2
      fi
      echo "==> Creating $vm (the first time this downloads Ubuntu and takes a few minutes)"
      limactl create --tty=false --name="$vm" --vm-type="$VM_TYPE" "lima/$vm.yaml"
      limactl start --tty=false "$vm"
      ;;
    *)
      echo "$vm is in state '$status'. Try: limactl stop -f $vm && bash servers/up.sh  (or start over: bash servers/delete.sh)" >&2
      exit 1
      ;;
  esac
done

echo
bash ./status.sh
