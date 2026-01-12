#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Proxmox OVS Port Mirroring Hookscript (Advanced: VLAN Filtered)
# ------------------------------------------------------------------------------
# This script mirrors traffic from an OVS bridge to a specific VM interface.
# ADVANCED FEATURE: Only mirrors traffic belonging to specific VLAN IDs.
# ==============================================================================

VM_ID="${1:-}"
EXECUTION_PHASE="${2:-}"

# ------------------------------------------------------------------------------
# User Configuration
# ------------------------------------------------------------------------------

# The OVS Bridge to monitor
VM_BRIDGE="vmbr2"

# The output NIC index on the monitoring VM (1 = net1)
MIRROR_NIC_INDEX="1"

# [ADVANCED] Target VLANs to monitor.
# Add VLAN IDs here (e.g., 10 20 30).
# If this array is empty, ALL traffic (all VLANs) will be mirrored.
TARGET_VLANS=(10 20)

# Log file path
LOGGING="/root/scripts/port-mirror-vlan.log"

# ------------------------------------------------------------------------------
# Internal Logic
# ------------------------------------------------------------------------------

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VM $VM_ID] $*" >> "$LOGGING"
}

# Check prerequisites
check_prereqs() {
  if ! /usr/bin/ovs-vsctl --if-exists get Bridge "$VM_BRIDGE" _uuid >/dev/null 2>&1; then
    log "ERROR: Bridge '$VM_BRIDGE' is not a valid OVS bridge."
    return 1
  fi
  return 0
}

get_tap_interface() {
  echo "tap${VM_ID}i${MIRROR_NIC_INDEX}"
}

create_mirror() {
  local tap
  tap=$(get_tap_interface)
  local mirror_name="${VM_ID}-vlan-mirror"
  
  if ! /usr/bin/ovs-vsctl --if-exists get Port "$tap" _uuid >/dev/null 2>&1; then
    log "WARN: Output port '$tap' not found. Skipping."
    return 0
  fi

  # Prepare VLAN Argument
  local vlan_arg=""
  local msg_suffix="(ALL VLANs)"
  
  if [ ${#TARGET_VLANS[@]} -gt 0 ]; then
    # Join array with commas (e.g., "10,20")
    local vlan_list
    vlan_list=$(IFS=, ; echo "${TARGET_VLANS[*]}")
    vlan_arg="select-vlan=$vlan_list"
    msg_suffix="(VLANs: $vlan_list)"
  fi

  log "Creating mirror '$mirror_name' on '$VM_BRIDGE' -> '$tap' $msg_suffix"

  # Clean up any existing mirror with this name first
  /usr/bin/ovs-vsctl --if-exists destroy Mirror "$mirror_name" >> "$LOGGING" 2>&1 || true

  # Create the Mirror
  # We use select-all=true to capture traffic on the bridge, 
  # but verify it against select-vlan if provided.
  /usr/bin/ovs-vsctl \
    -- --id="@tap" get Port "$tap" \
    -- --id="@m" create Mirror name="$mirror_name" \
      select-all=true \
      $vlan_arg \
      output-port="@tap" \
    -- add Bridge "$VM_BRIDGE" mirrors "@m" \
    >> "$LOGGING" 2>&1

  log "SUCCESS: Mirror created."
}

clear_mirror() {
  local mirror_name="${VM_ID}-vlan-mirror"
  
  log "Removing mirror '$mirror_name'..."

  /usr/bin/ovs-vsctl \
    -- --id="@m" get Mirror "$mirror_name" \
    -- remove Bridge "$VM_BRIDGE" mirrors "@m" \
    >> "$LOGGING" 2>&1 || true

  /usr/bin/ovs-vsctl --if-exists destroy Mirror "$mirror_name" >> "$LOGGING" 2>&1 || true
  
  log "SUCCESS: Mirror removed."
}

# ------------------------------------------------------------------------------
# Main Execution Flow
# ------------------------------------------------------------------------------

if [[ -z "$VM_ID" || -z "$EXECUTION_PHASE" ]]; then
  echo "Usage: $0 <VM_ID> <PHASE>"
  exit 1
fi

case "$EXECUTION_PHASE" in
  post-start)
    # Check bridge existence before waiting
    if check_prereqs; then
      # Wait for KVM to initialize tap interfaces
      sleep 30
      create_mirror
      # Optional: Log current mirrors for debugging
      # /usr/bin/ovs-vsctl list Mirror >> "$LOGGING"
    fi
    ;;
  pre-stop)
    if check_prereqs; then
      clear_mirror
    fi
    ;;
esac

exit 0
