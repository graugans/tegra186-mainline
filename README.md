# tegra186-mainline

Bring a current **vanilla mainline LTS kernel** to the **NVIDIA Jetson TX2 NX**
(Tegra186), which NVIDIA left on JetPack 4.6.6 / kernel 4.9.

- Kernel: latest mainline LTS, currently **v6.18** (pinned in [kernel/VERSION](kernel/VERSION))
- Rootfs: **OpenEmbedded / Yocto wrynose** (6.0), built with kas, served via NFS
- Boot: L4T boot chain + L4T U-Boot unchanged, kernel + DTB via TFTP/PXE
- Lab: labgrid + Norn relay board for power/buttons, USB-UART console

The full plan (decisions, phases, acceptance criteria) is in
[docs/plan.md](docs/plan.md). Decisions are in [docs/decisions/](docs/decisions/),
test runs in [docs/bringup-log.md](docs/bringup-log.md).

## Status

| Phase | State |
|---|---|
| 0 – Scaffolding | in progress: repo, dev container, kernel build (v6.18.62 defconfig) and wrynose rootfs build done; lab network, UART, Compose stack open |
| 1a – Netboot with L4T 4.9 | open |
| 1b – Mainline to a shell (initramfs) | open |
| 1c – Mainline with NFS root | open |
| 2 – Test loop | open |
| 3 – DTB fixups | open |
| 4 – Generalize (BSP layer) | open |

## Repository layout

```
.devcontainer/   Dockerfile-based dev container (Debian 13 "trixie")
docs/            plan, bring-up log, decision records
kernel/          VERSION, config fragments, patch series (no sources)
bootloader/      U-Boot boot script/env, CBoot patches (slot B only)
yocto/kas/       kas configs for the rootfs
lab/             Compose stack, host setup files, labgrid config
scripts/         every manual step as a script
tests/           on-target tests run via SSH
logs/            per-run logs (git-ignored)
```

## Safety rules

- **Never** run fuse tools (`odmfuse.sh` or similar) – irreversible.
- Never flash QSPI/eMMC boot partitions, CBoot or U-Boot without explicit
  agreement. Bootloader changes go to **slot B** only; slot A is the fallback.
- No writes to the eMMC from test kernels or tests.
- Every boot has a hard timeout, followed by a power cycle.

---

## Setup

The host is the lab PC (tested with Fedora 44). Everything that needs root on
the host is listed here and done **by hand**; the dev container never changes
host settings.

### 1. Host prerequisites

- Docker Engine with the Compose plugin, user in the `docker` group
- VS Code with the *Dev Containers* extension (`ms-vscode-remote.remote-containers`)
- ~150 GB free next to the repo for build data (Yocto downloads, sstate, kernel tree)

### 2. Clone

```sh
git clone git@github.com:graugans/tegra186-mainline.git
cd tegra186-mainline
```

The dev container stores its build data in a sibling directory
`../tegra186-work` (created automatically, mounted at `/work`).

### 3. Open the dev container

In VS Code: *Dev Containers: Reopen in Container*
(or from the CLI: `devcontainer up --workspace-folder .`).

The image is built from [.devcontainer/Dockerfile](.devcontainer/Dockerfile):
Debian 13, Yocto host packages, `aarch64-linux-gnu` toolchain, ccache, dtc,
u-boot-tools, kas, labgrid client, Claude Code CLI, plus VS Code extensions
(Claude Code, BitBake, devicetree, YAML, Python, ShellCheck).

Inside the container:

| Path | Purpose |
|---|---|
| repo | mounted at the same path as on the host |
| `/work/ccache` | ccache (`CCACHE_DIR`) |
| `/work/yocto` | kas work dir, downloads, sstate (`KAS_WORK_DIR`, `DL_DIR`, `SSTATE_DIR`) |
| `~/.claude` | shared with the host (Claude Code login and memory) |

`ARCH=arm64` and `CROSS_COMPILE=aarch64-linux-gnu-` are preset.

Quick check:

```sh
aarch64-linux-gnu-gcc --version && kas --version && claude --version
```

### 4. Build the kernel (inside the container)

```sh
scripts/kernel-build.sh                 # arm64 defconfig only
scripts/kernel-build.sh nfs-root.cfg    # plus fragments from kernel/configs/
```

Shallow-clones the stable tree at the tag in [kernel/VERSION](kernel/VERSION)
to `/work/linux` (reset to the tag on every run), applies
`kernel/patches/*.patch`, builds out of tree in `/work/kernel-build` with
ccache. Result in `/work/kernel-out/`: `Image`,
`tegra186-p3509-0000+p3636-0001.dtb`, `config`, `modules/`, `VERSION`.

### 5. Build the rootfs (inside the container)

```sh
scripts/rootfs-build.sh
```

Creates `/work/yocto` (and the downloads/sstate dirs) and runs
`kas build yocto/kas/tx2nx-rootfs.yml`. Calling kas directly on a fresh
`/work` fails because kas does not create missing parents of its build dir.

Layer commits are pinned in
[yocto/kas/tx2nx-rootfs.lock.yml](yocto/kas/tx2nx-rootfs.lock.yml); run
`kas lock yocto/kas/tx2nx-rootfs.yml` to move to newer wrynose commits.
The first build from scratch takes about an hour (16 cores, 4826 tasks)
and uses about 53 GB in `/work/yocto` (downloads, sstate, tmp);
rebuilds from sstate take under a minute.

Result: `/work/yocto/build/tmp/deploy/images/genericarm64/core-image-minimal-genericarm64.rootfs.tar.zst`

### 6. Host: TFTP and NFS directories (manual, as root)

> Run on the host, not in the container.

```sh
# TFTP root, writable by your user (the dev container runs with your UID)
sudo install -d -o "$USER" -g "$USER" /srv/tftp

# NFS root, owned by root; only the rootfs-helper writes here
sudo install -d -o root -g root /srv/nfs/tx2nx

# NFS server
sudo dnf install -y nfs-utils
echo '/srv/nfs/tx2nx 192.168.77.0/24(rw,no_root_squash,no_subtree_check,sync)' \
  | sudo tee /etc/exports.d/tx2nx.exports
sudo systemctl enable --now nfs-server
sudo exportfs -ra && sudo exportfs -v
```

`no_root_squash` is required for a root filesystem – keep the export restricted
to the isolated lab subnet.

### 7. Host: lab network (manual, as root) – *TODO, next session*

Dedicated USB NIC on an isolated subnet (`192.168.77.0/24`, host `.1`),
NFS/DHCP/TFTP reachable only on that interface (firewalld zone). Exact
interface name and commands will be added here.

### 8. Host: UART and Norn – *TODO, next session*

USB-UART adapter (stable `/dev/serial/by-id/...` path), Norn REST service on
the host, then the Compose stack in `lab/` (dnsmasq, labgrid, rootfs-helper).
Afterwards `/srv/tftp` and the UART get mounted into the dev container.

---

## Conventions

- Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat`, `fix`, `docs`, `build`, `chore`, `test`, …), one step per commit.
- One variable per test step; every run gets a `logs/<run-id>/` directory and
  an entry in [docs/bringup-log.md](docs/bringup-log.md).

## License

[Apache-2.0](LICENSE)
