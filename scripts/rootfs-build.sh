#!/usr/bin/env bash
# Build the Yocto wrynose NFS rootfs inside the dev container.
#
#   scripts/rootfs-build.sh [kas args ...]
#
# Uses KAS_WORK_DIR, DL_DIR and SSTATE_DIR from the container environment
# (defaults below). Output:
#   $KAS_WORK_DIR/build/tmp/deploy/images/genericarm64/
#       core-image-minimal-genericarm64.rootfs.tar.zst
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export KAS_WORK_DIR=${KAS_WORK_DIR:-/work/yocto}
export DL_DIR=${DL_DIR:-$KAS_WORK_DIR/downloads}
export SSTATE_DIR=${SSTATE_DIR:-$KAS_WORK_DIR/sstate-cache}

# kas creates the build dir with a plain mkdir, so its parent must exist.
mkdir -p "$KAS_WORK_DIR" "$DL_DIR" "$SSTATE_DIR"

exec kas build "$@" "$REPO_DIR/yocto/kas/tx2nx-rootfs.yml"
