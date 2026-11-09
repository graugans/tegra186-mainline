#!/usr/bin/env bash
# Ask the rootfs-helper (lab Compose stack, runs as root on the host) to act
# on the NFS rootfs. The dev container never writes /srv/nfs/tx2nx itself.
#
#   scripts/rootfs.sh status     show rootfs and kernel-out state
#   scripts/rootfs.sh reset      wipe and unpack the Yocto rootfs tarball
#   scripts/rootfs.sh modules    install /work/kernel-out modules into it
set -euo pipefail

URL=${ROOTFS_HELPER_URL:-http://127.0.0.1:${ROOTFS_HELPER_PORT:-8091}}

case ${1:-} in
    status)  exec curl -fsS "$URL/status" ;;
    reset)   path=/rootfs/reset ;;
    modules) path=/modules/install ;;
    *) echo "usage: $0 status|reset|modules" >&2; exit 2 ;;
esac

# --fail-with-body: print the helper's JSON error and exit non-zero on 4xx/5xx.
curl -sS --fail-with-body -X POST --max-time 600 "$URL$path"
