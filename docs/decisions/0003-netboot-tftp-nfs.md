# 0003 – Netboot: TFTP/PXE kernel, NFS rootfs

Status: accepted (2026-11-09)

**Decision:** U-Boot fetches kernel + DTB via `pxe get` over TFTP. The Yocto
rootfs is served via NFS from the host. dnsmasq (DHCP + TFTP) runs in Docker
Compose with `network_mode: host`, bound to an isolated lab interface only.
The NFS server runs natively on the host.

**Consequences:** No writes to eMMC during tests; the rootfs is reset only through
the rootfs-helper. `no_root_squash` export is restricted to the lab subnet.
