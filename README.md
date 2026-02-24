# homelab-tutorial

Use this repository in this order:

1) Read `proxmox-security-architecture/README.md` first for the full overview and standard OVS mirroring flow.
2) Read `proxmox-security-architecture/README-VLAN.md` if you need VLAN-filtered mirroring.
3) Review the scripts (`proxmox-security-architecture/port-mirror.sh` and `proxmox-security-architecture/port-mirror-vlan.sh`) and apply only the required config values.

Quick reference:

- Full traffic mirroring (default): `proxmox-security-architecture/README.md`
- VLAN-filtered mirroring: `proxmox-security-architecture/README-VLAN.md`
- VM configuration example: `proxmox-security-architecture/README.md`

Read the docs first, then make minimal config changes in the scripts.
