#!/usr/bin/env bash
# Show the two lab servers and whether their app answers on the Mac.
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
require_lima

printf '%-12s %-9s %-24s %s\n' SERVER STATUS APP "APP HEALTH"
for vm in "${VMS[@]}"; do
  status="$(vm_status "$vm")"
  port="$(app_port_of "$vm")"
  url="http://localhost:$port"
  health="-"
  if [[ "$status" == "Running" ]]; then
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$url/health" || true)"
    case "$code" in
      200) health="OK (200)" ;;
      000) health="no answer (nothing deployed yet?)" ;;
      *)   health="HTTP $code" ;;
    esac
  fi
  printf '%-12s %-9s %-24s %s\n' "$vm" "${status:-missing}" "$url" "$health"
done
