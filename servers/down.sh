#!/usr/bin/env bash
# Stop the two lab servers (they keep their disks; bash servers/up.sh starts them again).
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
require_lima

for vm in "${VMS[@]}"; do
  case "$(vm_status "$vm")" in
    Running) echo "==> Stopping $vm"; limactl stop "$vm" ;;
    "")      echo "==> $vm does not exist" ;;
    *)       echo "==> $vm is not running" ;;
  esac
done
