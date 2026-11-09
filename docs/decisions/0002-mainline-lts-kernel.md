# 0002 – Current mainline LTS kernel

Status: accepted (2026-11-09)

**Context:** JetPack 4.6.6 (kernel 4.9) is the last release for the TX2 NX.
JetPack 6 (5.15) has no Tegra186 support. Mainline supports the board via
`tegra186-p3509-0000+p3636-0001.dts`.

**Decision:** Use the current mainline LTS kernel. No sources in the repo:
upstream tag + patch series in `kernel/patches/`, config fragments in
`kernel/configs/`. Built with `make` + ccache, not via Yocto.
