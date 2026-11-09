# 0006 – Yocto/OpenEmbedded wrynose for the rootfs

Status: accepted (2026-11-09)

**Decision:** The NFS rootfs is built with OpenEmbedded **wrynose** (Yocto 6.0, LTS)
via kas: bitbake `2.18`, openembedded-core / meta-yocto / meta-openembedded on
branch `wrynose`. Machine `genericarm64`; the kernel recipe is replaced by
`linux-dummy` because the kernel is built outside Yocto (see 0002).

**Consequences:** Kernel modules are installed into the rootfs by the
rootfs-helper, not by the image.
