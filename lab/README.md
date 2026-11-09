# lab

Host-side lab services. They run **on the lab host** with Docker Compose, all
with `network_mode: host`; the dev container talks to them over localhost.

| Service | Purpose | Listens on |
|---|---|---|
| `dnsmasq` | DHCP (exactly one address, `BOARD_IP`) + TFTP from `/srv/tftp`; no DNS, no default route | `LAB_IF` only |
| `iperf3-server` | lab service for throughput tests | `LAB_HOST_IP:5201` |
| `rootfs-helper` | only writer of `/srv/nfs/tx2nx` (runs as root) | `127.0.0.1:8091` |
| `labgrid-coordinator` | labgrid coordinator | `127.0.0.1:20408` |
| `labgrid-exporter` | UART + Norn power port (profile `board`) | – |

NFS server and Norn run natively on the host (see top-level README).

## Settings

Defaults live in [compose.yaml](compose.yaml). Override them in `lab/.env`
(git-ignored), for example:

```sh
LAB_IF=enp48s0f3u1u3        # lab NIC on the host
LAB_HOST_IP=192.168.0.201   # host address on LAB_IF (static, set on the host)
LAB_NETMASK=255.255.255.0
BOARD_IP=192.168.0.69       # the only address dnsmasq hands out
BOARD_MAC=                  # optional: reserve BOARD_IP for this MAC
TFTP_ROOT=/srv/tftp
NFS_ROOT=/srv/nfs/tx2nx
WORK_DIR=../../tegra186-work   # dev container /work (kernel-out, yocto)
ROOTFS_HELPER_PORT=8091
LAB_UART=/dev/ttyUSB0       # later: /dev/serial/by-id/...
NORN_URL=http://localhost:8080
```

## Usage (on the host)

```sh
docker compose -f lab/compose.yaml up -d --build              # dnsmasq, iperf3, rootfs-helper, coordinator
docker compose -f lab/compose.yaml --profile board up -d      # + labgrid exporter (UART + Norn wired)
docker compose -f lab/compose.yaml logs -f dnsmasq            # watch DHCP/TFTP
```

From the dev container: `scripts/rootfs.sh status|reset|modules`.

## rootfs-helper

[rootfs-helper/rootfs-helper.py](rootfs-helper/rootfs-helper.py) offers fixed
actions only, without parameters:

- `GET /status` – rootfs tarball last unpacked, `/work/kernel-out/VERSION`, free space
- `POST /rootfs/reset` – wipe `NFS_ROOT` (same filesystem only) and unpack the
  Yocto rootfs tarball from `/work/yocto/.../deploy/images/genericarm64/`
- `POST /modules/install` – rsync `/work/kernel-out/modules/lib/modules/<release>`
  into the rootfs (owned by root, without the `build`/`source` links)

`/work` is mounted read-only; symlinks inside the rootfs are resolved relative
to `NFS_ROOT` and may not point outside of it.

## Layout

```
compose.yaml              the stack
images/services/          Debian image: dnsmasq, iperf3, python3, tar/zstd, rsync
images/labgrid/           Debian image: labgrid (same version as the dev container), ser2net
dnsmasq/entrypoint.sh     renders the dnsmasq config from the environment
rootfs-helper/            rootfs-helper service
labgrid/exporter.yaml     exporter resources (UART, Norn)
host/                     files for manual host setup (NFS export)
```
