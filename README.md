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


# Why Use Proxmox When ESXi Is the More Popular Choice?

`A common question is: "Why use Proxmox when ESXi is the industry-standard and more widely adopted hypervisor?"`

In fact, if you look at the older PDF materials from 2022, the project was originally built on an ESXi-based environment.

ESXi makes it much easier to create SPAN ports through its internal virtual switch, and its UI/UX is significantly more intuitive and stable. For network and security lab environments, ESXi provides a very polished experience.

However, the biggest issue is hardware compatibility. ESXi is highly dependent on vendor-specific NICs and motherboard support, which makes it difficult to run on a typical personal desktop PC. It is technically possible if you downgrade to an older version, but compatibility is still limited.

More importantly, because of the trial license restrictions, I could not realistically use ESXi during my undergraduate years when I had very limited financial resources.

For that reason, I migrated the project to Proxmox and implemented the required functionality using more complex hook scripts. Although this approach is less elegant than ESXi’s native virtual networking features, it provides excellent flexibility and works reliably on consumer hardware.

That said, if budget is not a concern, I would still recommend practicing with ESXi for this type of virtualization and network-security lab environment, as its virtual switch management, SPAN configuration, and overall operational experience are generally superior for educational and enterprise-style training scenarios.
