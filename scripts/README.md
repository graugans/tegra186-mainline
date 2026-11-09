# scripts

Every manual step lives here as a script (build, deploy, power-cycle,
console-expect, ssh-run, rootfs-reset).

| Script | Purpose |
|---|---|
| `kernel-build.sh [fragment.cfg ...]` | clone pinned tag, apply patches, defconfig + fragments, build Image/DTB/modules into `/work/kernel-out` |
| `rootfs-build.sh [kas args ...]` | create `/work/yocto` dirs, `kas build` the wrynose NFS rootfs |
