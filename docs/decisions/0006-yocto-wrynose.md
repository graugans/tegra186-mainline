# 0006 – Yocto/OpenEmbedded wrynose for the rootfs

Status: accepted (2026-11-09)

**Decision:** The NFS rootfs is built with OpenEmbedded **wrynose** (Yocto 6.0, LTS)
via kas: bitbake `2.18`, openembedded-core / meta-yocto / meta-openembedded on
branch `wrynose`. Machine `genericarm64`; the kernel recipe is replaced by
`linux-dummy` because the kernel is built outside Yocto (see 0002).

**Consequences:** Kernel modules are installed into the rootfs by the
rootfs-helper, not by the image.

Layer commits are pinned in `yocto/kas/tx2nx-rootfs.lock.yml` (generated
with `kas lock`, picked up automatically by kas); update it deliberately with
`kas lock` rather than floating on the branch heads.
