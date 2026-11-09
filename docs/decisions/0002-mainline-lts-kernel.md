# 0002 – Latest vanilla mainline LTS kernel

Status: accepted (2026-11-09)

**Context:** JetPack 4.6.6 (kernel 4.9) is the last release for the TX2 NX.
JetPack 6 (5.15) has no Tegra186 support. Mainline supports the board via
`tegra186-p3509-0000+p3636-0001.dts`.

**Decision:** Track the latest vanilla mainline LTS kernel from the stable tree
(`git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git`). As of 2026-11-09
this is **6.18** (`v6.18.62`). The exact tag is pinned in `kernel/VERSION`.
No sources in the repo: upstream tag + patch series in `kernel/patches/`,
config fragments in `kernel/configs/`. Built with `make` + ccache, not via Yocto.

**Consequences:** Bumping the stable point release is one change step on its own.
Moving to the next LTS series is a separate decision record.
