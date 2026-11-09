#!/bin/sh
# Render the dnsmasq config from the environment and run in the foreground.
# DHCP hands out exactly one address (BOARD_IP); with BOARD_MAC set it is
# reserved for that MAC. No DNS, no default route, TFTP from /srv/tftp.
set -eu
: "${LAB_IF:?}" "${LAB_HOST_IP:?}" "${LAB_NETMASK:?}" "${BOARD_IP:?}"

conf=/tmp/dnsmasq.conf
cat > "$conf" <<CONF
port=0
interface=${LAB_IF}
bind-dynamic
log-facility=-
log-dhcp
dhcp-authoritative
dhcp-range=${BOARD_IP},${BOARD_IP},${LAB_NETMASK},1h
dhcp-option=option:router
dhcp-option=option:dns-server
dhcp-option-force=option:tftp-server,${LAB_HOST_IP}
enable-tftp
tftp-root=/srv/tftp
CONF
if [ -n "${BOARD_MAC:-}" ]; then
    echo "dhcp-host=${BOARD_MAC},${BOARD_IP}" >> "$conf"
fi

echo "--- $conf"; cat "$conf"; echo "---"
exec dnsmasq --keep-in-foreground --conf-file="$conf"
