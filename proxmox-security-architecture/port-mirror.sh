#!/usr/bin/env bash
set -euo pipefail

VM_ID="${1:-""}"
EXECUTION_PHASE="${2:-""}"

VM_BRIDGE="vmbr2"
LOGGING="/root/scripts/port-mirror.log"

# Which NIC indexes should receive mirrored traffic as output ports.
# Default: both 0 and 1 (net0 and net1).
# If you want only one side, e.g. only net1:

MIRROR_NIC_INDEXES=("1")

log() {
  /usr/bin/date >> "$LOGGING"
  /usr/bin/echo "$*" >> "$LOGGING"
}

# Check whether an OVS port exists
port_exists() {
  local port="$1"
  /usr/bin/ovs-vsctl --if-exists get Port "$port" _uuid >/dev/null 2>&1
}

# Check whether the bridge exists and is an OVS bridge
bridge_exists() {
  /usr/bin/ovs-vsctl --if-exists get Bridge "$VM_BRIDGE" _uuid >/dev/null 2>&1
}

# Create a mirror for a specific NIC index
create_mirror_for_idx() {
  local idx="$1"
  local tap="tap${VM_ID}i${idx}"
  local mirror="${VM_ID}-mirror-i${idx}"

  if ! bridge_exists; then
    log "ERROR: Bridge '$VM_BRIDGE' not found as an OVS bridge (is it a Linux bridge?). Skipping."
    return 0
  fi

  if ! port_exists "$tap"; then
    log "WARN: Port '$tap' not found on OVS. Skipping mirror creation for idx=${idx}."
    return 0
  fi

  log "Creating mirror '$mirror' on bridge '$VM_BRIDGE' with output-port '$tap' (select-all=true)"

  # Remove an existing mirror with the same name, if any, before creating a new one
  /usr/bin/ovs-vsctl --if-exists destroy Mirror "$mirror" >> "$LOGGING" 2>&1 || true

  /usr/bin/ovs-vsctl \
    -- --id=@tap" get Port "$tap" \
    -- --id=@m" create Mirror name="$mirror" \
      select-all=true \
      output-port="@tap" \
    -- add Bridge "$VM_BRIDGE" mirrors "@m" \
    >> "$LOGGING" 2>&1

  log "OK: mirror '$mirror' created"
}

# Remove a mirror for a specific NIC index
clear_mirror_for_idx() {
  local idx="$1"
  local mirror="${VM_ID}-mirror-i${idx}"

  if ! bridge_exists; then
    log "WARN: Bridge '$VM_BRIDGE' not found as an OVS bridge. Skipping mirror cleanup."
    return 0
  fi

  log "Clearing mirror '$mirror' from bridge '$VM_BRIDGE'"

  # Remove the mirror reference from the bridge (ignore errors if it does not exist)
  /usr/bin/ovs-vsctl \
    -- --id=@m" get Mirror "$mirror" \
    -- remove Bridge "$VM_BRIDGE" mirrors "@m" \
    >> "$LOGGING" 2>&1 || true

  # Destroy the mirror object itself
  /usr/bin/ovs-vsctl --if-exists destroy Mirror "$mirror" >> "$LOGGING" 2>&1 || true

  log "OK: mirror '$mirror' cleared"
}

# Log currently existing mirrors
show_mirrors() {
  log "Show existing mirrors:"
  /usr/bin/ovs-vsctl list Mirror >> "$LOGGING" 2>&1 || true
  log "####################"
}

# If required arguments are missing, do nothing and do not block the VM lifecycle
if [[ -z "$VM_ID" || -z "$EXECUTION_PHASE" ]]; then
  log "Missing args: VM_ID='${VM_ID}' PHASE='${EXECUTION_PHASE}' (ignored)"
  exit 0
fi

case "$EXECUTION_PHASE" in
  post-start)
    # Wait to avoid timing issues while tap ports are being created
    sleep 30
    for idx in "${MIRROR_NIC_INDEXES[@]}"; do
      create_mirror_for_idx "$idx"
    done
    show_mirrors
    ;;
  pre-stop)
    for idx in "${MIRROR_NIC_INDEXES[@]}"; do
      clear_mirror_for_idx "$idx"
    done
    show_mirrors
    ;;
  *)
    # Ignore other lifecycle phases
    log "Ignoring phase: ${EXECUTION_PHASE} for VM ${VM_ID}"
    exit 0
    ;;
esac
