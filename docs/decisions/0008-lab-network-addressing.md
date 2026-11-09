# 0008 – Lab network addressing and host services

Status: accepted (2026-11-09)

**Context:** The lab host has a dedicated USB NIC (`enp48s0f3u1u3`) with a
static `192.168.0.201/24`. The segment behind it is isolated: only the host
and the TX2 NX, no router, no other DHCP server.

**Decision:**
- Board address `192.168.0.69`. dnsmasq hands out exactly this one address
  (single-address range; optional `dhcp-host` reservation by MAC once known),
  without default route or DNS, and serves TFTP from `/srv/tftp`.
- Interface, addresses and paths are Compose variables (defaults in
  `lab/compose.yaml`, overrides in git-ignored `lab/.env`).
- NFS export limited to the board IP, not the whole /24.
- Lab services (dnsmasq, iperf3-server, rootfs-helper, labgrid coordinator,
  exporter) run in Compose with host networking. The rootfs-helper and the
  coordinator listen on 127.0.0.1 only; the dev container reaches them over
  localhost. The rootfs-helper offers fixed actions only (reset, modules,
  status).
- labgrid reaches Norn over the network via its REST power port (`NORN_URL`).
- Host firewall: a dedicated firewalld zone on the lab NIC opens DHCP, TFTP,
  NFS (v3: mountd, rpc-bind) and iperf3 only there. Applied by hand.

**Consequences:** A second board needs a wider DHCP range or MAC
reservations. `192.168.0.0/24` is a common home subnet; the lab NIC must never
be bridged to another network.
