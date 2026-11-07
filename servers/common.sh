# Shared settings for the servers/*.sh scripts. Not meant to be run on its own.

# The two lab servers, and the app port each one exposes on your Mac (http://localhost:<port>).
VMS=(lab-staging lab-prod)
app_port_of() {
  case "$1" in
    lab-staging) echo 8081 ;;
    lab-prod) echo 8082 ;;
  esac
}

require_lima() {
  if ! command -v limactl >/dev/null 2>&1; then
    echo "limactl not found. Install Lima first:  brew install lima" >&2
    exit 1
  fi
}

# Prints Running, Stopped, ... or nothing when the VM does not exist yet.
vm_status() {
  limactl list --format '{{.Status}}' "$1" 2>/dev/null || true
}
