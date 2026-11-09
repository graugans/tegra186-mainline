# tegra186-mainline – Project Plan

First target board: Jetson TX2 NX.

Goal: Run the Jetson TX2 NX (Tegra186) on a current mainline LTS kernel.
The kernel is loaded via TFTP/PXE, the rootfs (Yocto) is served via NFS. The test
loop runs automatically through labgrid and Norn, driven by Claude Code inside
the dev container.

Background: The TX2 NX is stuck on JetPack 4.6.6 (L4T R32.7.6, kernel 4.9,
Ubuntu 18.04). This is the final release; NVIDIA no longer ships security
updates. Mainline already supports the board via the DTS
`tegra186-p3509-0000+p3636-0001.dts`.

---

## Decisions

| Topic | Decision |
|---|---|
| Boot chain | MB1/MB2/BPMP blobs and CBoot stay unchanged; U-Boot from L4T stays (possibly patched in phase 3) |
| Kernel | Latest vanilla mainline LTS (currently 6.18), not the 5.15 from JetPack 6 (NVIDIA provides no T186 support there) |
| Kernel transport | TFTP, driven by `pxe get` in U-Boot |
| Rootfs | Yocto/OpenEmbedded wrynose (6.0 LTS), via NFS from the host |
| meta-tegra | Not needed for the kernel; only as the source for CBoot sources (L4T R32.7.x branch) |
| NFS server | Native on the host (no container) |
| DHCP/TFTP | dnsmasq in Docker Compose, `network_mode: host` |
| Board control | labgrid (coordinator + exporter) in Compose |
| Power/buttons | Norn (Waveshare Pico Relay B, labgrid-compatible REST API, `cycle` for button pulses), runs on the host |
| Console | USB-UART adapter on the debug UART |
| Dev environment | Dockerfile-based dev container on the latest Debian stable (13 "trixie") with toolchain, kas, labgrid client, Claude Code |
| Hosting | GitHub, hosting only, no CI/CD |
| Audience | Author only, no students for now |

---

## Architecture

```
Lab host
├── native
│   ├── NFS server       → /srv/nfs/tx2nx
│   └── Norn             → relays (power, reset, recovery, power button)
├── docker compose (network_mode: host)
│   ├── dnsmasq          → DHCP + TFTP (/srv/tftp), lab interface only
│   ├── iperf3-server    → lab service for throughput tests
│   ├── labgrid          → coordinator + exporter (UART, Norn port)
│   └── rootfs-helper    → runs as root, resets rootfs, installs modules
└── Dev container (no root rights on shared paths)
    ├── cross toolchain, ccache, dtc, u-boot-tools, kas, labgrid client
    └── Claude Code
```

### Shared directories

| Path | Written by | Read by |
|---|---|---|
| `/srv/tftp` | dev container (Image, DTB, PXE config) | dnsmasq |
| `/srv/nfs/tx2nx` | rootfs-helper (as root) | NFS server, board |
| `logs/` | labgrid exporter, test scripts | dev container |
| sstate/downloads cache | dev container (volumes) | dev container |

### Lab network

- Dedicated USB NIC `enp48s0f3u1u3` on the host, isolated segment (host + board only)
- Host `192.168.0.201/24` (static), board `192.168.0.69` (only DHCP address handed out); see decision 0008
- dnsmasq and NFS bound to this interface only
- No DHCP leaking into the university/company network

### Relay mapping (Norn)

| Channel | Function |
|---|---|
| 1 | Carrier board power supply |
| 2 | Reset button (pulse via `cycle`) |
| 3 | Force recovery button (pulse via `cycle`) |
| 4 | Power button (pulse via `cycle`) |
| 5–8 | spare |

The button relays are wired in parallel to the pins on the carrier board's button header.

---

## Phases

### Phase 0 – Scaffolding
- Repo structure, dev container, Docker Compose (dnsmasq, labgrid, rootfs-helper)
- Host setup: lab interface, NFS export, Norn service
- kas file for a minimal Yocto rootfs (SSH, kselftest/LTP, ethtool, iperf3)
- labgrid environment with UART and Norn port

**Done when:** `labgrid-client` can switch the board on and off and the UART
output of the existing L4T boot ends up in the log.

### Phase 1a – Netboot with the known kernel
- L4T U-Boot loads the **old** 4.9 kernel + DTB via TFTP/PXE
- Rootfs via NFS
- Validates DHCP, TFTP, NFS and the U-Boot environment without new unknowns

**Done when:** login via UART and SSH with 4.9 over NFS.

### Phase 1b – Mainline kernel to a shell (no network)
- Mainline LTS with `defconfig` + mainline DTB via TFTP
- Small initramfs (Busybox) instead of NFS
- U-Boot passes the **mainline DTB** via `booti`, not the one handed over by CBoot
- This shows whether BPMP, clocks and power domains work with the L4T firmware

**Done when:** shell on the UART, `dmesg` free of BPMP/clock errors.

### Phase 1c – Mainline kernel with NFS root
- NFS config fragment (see below), switch boot args
- Yocto rootfs over NFS

**Done when:**
- Login via UART and SSH
- `dmesg` free of BPMP, clock and Ethernet errors
- 10 consecutive power cycles boot reproducibly

### Phase 2 – Test loop
- Scripts: `build`, `deploy`, `power-cycle`, `console-expect`, `ssh-run`, `rootfs-reset`
- Flow: patch → build → deploy → power cycle → check UART → tests via SSH → log
- Unique run ID in kernel/rootfs, printed on the UART
- pytest + labgrid plugin in the dev container drive the board over serial and
  SSH; nothing runs pytest on the board (decision 0007)
- Tests declare their requirements as pytest markers (kernel version, config
  symbols, bootargs, userspace tools, lab services, timeout, thresholds);
  tests whose requirements the current build does not meet are deselected
- Lab service `iperf3-server` in the Compose stack for throughput tests
- Inspiration: Fabrizio Castro, Chris Paterson (Renesas): *Embedded Linux Kernel Testing With Pytest*,
  Open Source Summit / ELC Europe 2026, Prague –
  [talk page](https://osselceu2026.sched.com/event/2RaWL/embedded-linux-kernel-testing-with-pytest-fabrizio-castro-chris-paterson-renesas-electronics-europe-gmbh),
  [slides (PDF)](https://hosted-files.sched.co/osselceu2026/7f/OSS-EU_2026_Embedded-Linux-Kernel-Testing-With-Pytest.pdf)
  – the idea spark for marker-based test requirements

### Phase 3 – DTB fixups
1. Dump the CBoot DTB in U-Boot (`fdt addr`, `fdt print`) and compare with the mainline DTB
2. Add what is missing preferably in U-Boot (boot script or `ft_board_setup`)
3. Patch CBoot only if necessary (sources from meta-tegra), **slot B only**, slot A stays as fallback

Candidates: memory node (mainline DTS has a placeholder), reserved-memory/carveouts,
MAC address and serial number from EEPROM, `chosen`/boot args.

### Phase 4 – Generalize
- Consolidate the manual steps into a Yocto BSP layer (`meta-tx2nx-mainline`) and a labgrid configuration

---

## Configuration building blocks

### Kernel fragment `kernel/configs/nfs-root.cfg`
Everything **built-in** (`=y`), not as modules:
```
CONFIG_STMMAC_ETH=y
CONFIG_STMMAC_PLATFORM=y
CONFIG_DWMAC_DWC_QOS_ETH=y
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_NFS_FS=y
CONFIG_NFS_V3=y
CONFIG_ROOT_NFS=y
```
Add the PHY driver matching the fitted PHY (to be determined during bring-up).

### Boot args
```
console=ttyS0,115200n8 earlycon root=/dev/nfs nfsroot=192.168.0.201:/srv/nfs/tx2nx,v3,tcp ip=dhcp rw
```

### U-Boot environment (one-time, with local fallback)
```
setenv bootcmd 'dhcp; pxe get && pxe boot; run bootcmd_mmc0'
saveenv
```

### NFS export on the host `/etc/exports.d/tx2nx.exports`
```
/srv/nfs/tx2nx 192.168.0.69(rw,no_root_squash,no_subtree_check,sync)
```
`no_root_squash` is required for a root filesystem, so the export is restricted to the board IP
(file: `lab/host/tx2nx.exports`).

### labgrid resource for Norn
```yaml
NetworkPowerPort:
  model: rest
  host: 'http://localhost:8080/api/v1/relay/{index}/value'
  index: 1
```

---

## Repo structure

```
tegra186-mainline/
├── .devcontainer/
├── CLAUDE.md
├── docs/
│   ├── plan.md
│   ├── bringup-log.md
│   └── decisions/
├── kernel/
│   ├── configs/
│   └── patches/          # git format-patch series against upstream tag
├── bootloader/
│   ├── uboot/            # boot.scr, env, patches if needed
│   └── cboot/            # patches against meta-tegra sources
├── yocto/
│   ├── kas/
│   └── meta-tx2nx-mainline/
├── lab/
│   ├── compose.yaml
│   ├── host/             # exports, Norn service, network setup
│   └── labgrid/
├── scripts/
└── tests/
```

Kernel sources are not copied into the repo: reference an upstream tag and keep
our own changes as a patch series.

---

## Known pitfalls and open checks

- [ ] **BPMP ABI:** mainline kernel against L4T BPMP firmware – most likely to break first
- [ ] **CBoot patches the DTB** before handing it over; U-Boot must load the mainline DTB
- [ ] **Memory node** in the mainline DTS is a placeholder
- [ ] **A/B redundancy** in L4T: failed boots count against a retry counter → disable for the lab
- [ ] **Auto power-on** of the carrier board when power is applied – verify
- [ ] **Norn `cycle` via REST** available? Otherwise add an endpoint
- [ ] **`serverip` after `dhcp` in L4T U-Boot:** dnsmasq sends option 66 (TFTP server) but no boot file; verify U-Boot sets `serverip`, otherwise set it in the U-Boot env
- [ ] **USB mass storage in U-Boot** on T186 untested – TFTP is the default path
- [ ] **Rootfs permissions:** only the rootfs-helper unpacks/modifies the NFS rootfs
- [ ] **GPU:** Nouveau (gp10b) without CUDA; camera/ISP largely missing upstream
