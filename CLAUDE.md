# CLAUDE.md – tegra186-mainline

## Project
Bring a mainline LTS kernel to the Jetson TX2 NX (Tegra186). Kernel via
TFTP/PXE through the L4T U-Boot, Yocto rootfs via NFS. The full plan with
decisions, phases and acceptance criteria lives in `docs/plan.md` –
**read it before doing any work**.

## Environment
- You run inside the dev container. Toolchain, kas and labgrid client are here.
- Lab services run outside: dnsmasq, labgrid and rootfs-helper via Docker
  Compose (`lab/compose.yaml`); NFS server and Norn run natively on the host.
- Writable for you: `/srv/tftp`, `logs/`, the repo, the build caches.
- Do **not** modify `/srv/nfs/tx2nx` directly – only through the rootfs-helper.

## Test loop
1. Change (patch, config fragment, DTS)
2. Build (kernel with `make` + ccache, not via Yocto)
3. Deploy: Image, DTB, PXE config to `/srv/tftp`; modules via rootfs-helper
4. Reset the rootfs if the previous run may have modified it
5. Power cycle via labgrid/Norn
6. Evaluate the UART: wait for the login prompt or `Kernel panic`/hang, with timeout
7. Run tests via SSH
8. Store results in `logs/<run-id>/` and add an entry to `docs/bringup-log.md`

## Guardrails – non-negotiable
- **Never** use fuse tools (`odmfuse.sh` or similar). Irreversible.
- **Never** flash QSPI/eMMC boot partitions, CBoot or U-Boot without asking
  first. Bootloader changes go to **slot B** only; slot A stays untouched.
- No writes to the eMMC from test kernels or tests.
- Every boot has a hard timeout; after a timeout, power cycle – never wait forever.
- Change only one variable per step (see phases 1a → 1b → 1c).

## Way of working
- Capture every manual step immediately as a script (`scripts/`,
  `bootloader/uboot/boot.scr`, `kernel/configs/*.cfg`), not just as a note.
- Do not copy kernel sources into the repo: upstream tag + patch series in `kernel/patches/`.
- Record decisions briefly in `docs/decisions/`.
- When a check item in `docs/plan.md` is resolved, tick it off and note the result.
- When unsure about hardware or the boot chain: ask instead of guessing.
