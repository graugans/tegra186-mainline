#!/usr/bin/env bash
# Build the mainline kernel for the Jetson TX2 NX inside the dev container.
#
#   scripts/kernel-build.sh [fragment.cfg ...]
#
# - Source: stable tree at the tag pinned in kernel/VERSION, shallow clone in
#   $KERNEL_SRC (default /work/linux). The tree is reset to the tag on every
#   run, then kernel/patches/*.patch is applied with `git am`.
# - Config: arm64 defconfig plus the given fragments (paths, or names relative
#   to kernel/configs/), merged with scripts/kconfig/merge_config.sh.
# - Build: out of tree in $KERNEL_BUILD (default /work/kernel-build), ccache.
# - Output in $KERNEL_OUT (default /work/kernel-out):
#     Image, $DTB_NAME.dtb, config, modules/ (INSTALL_MOD_PATH staging), VERSION
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KERNEL_TAG=$(tr -d '[:space:]' < "$REPO_DIR/kernel/VERSION")
KERNEL_GIT=${KERNEL_GIT:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}
KERNEL_SRC=${KERNEL_SRC:-/work/linux}
KERNEL_BUILD=${KERNEL_BUILD:-/work/kernel-build}
KERNEL_OUT=${KERNEL_OUT:-/work/kernel-out}
DTB_NAME=${DTB_NAME:-tegra186-p3509-0000+p3636-0001}
JOBS=${JOBS:-$(nproc)}

export ARCH=arm64
export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}

log() { printf '>>> %s\n' "$*"; }

# --- source ------------------------------------------------------------------
if [[ ! -d $KERNEL_SRC/.git ]]; then
    log "cloning $KERNEL_TAG into $KERNEL_SRC"
    git clone --depth 1 --branch "$KERNEL_TAG" "$KERNEL_GIT" "$KERNEL_SRC"
elif ! git -C "$KERNEL_SRC" rev-parse -q --verify "refs/tags/$KERNEL_TAG" >/dev/null; then
    log "fetching $KERNEL_TAG"
    git -C "$KERNEL_SRC" fetch --depth 1 origin tag "$KERNEL_TAG"
fi

log "resetting $KERNEL_SRC to $KERNEL_TAG"
git -C "$KERNEL_SRC" am --abort >/dev/null 2>&1 || true
git -C "$KERNEL_SRC" checkout -q -f --detach "refs/tags/$KERNEL_TAG"
git -C "$KERNEL_SRC" clean -q -fdx

shopt -s nullglob
patches=("$REPO_DIR"/kernel/patches/*.patch)
if (( ${#patches[@]} )); then
    log "applying ${#patches[@]} patch(es)"
    git -C "$KERNEL_SRC" -c user.name=build -c user.email=build@localhost \
        am -q --committer-date-is-author-date "${patches[@]}"
fi

# --- config ------------------------------------------------------------------
fragments=()
for arg in "$@"; do
    f=$arg
    [[ -f $f ]] || f="$REPO_DIR/kernel/configs/$arg"
    [[ -f $f ]] || { echo "fragment not found: $arg" >&2; exit 1; }
    fragments+=("$(realpath "$f")")
done

mkdir -p "$KERNEL_BUILD"
make_k() { make -C "$KERNEL_SRC" O="$KERNEL_BUILD" CC="ccache ${CROSS_COMPILE}gcc" -j"$JOBS" "$@"; }

log "defconfig + ${#fragments[@]} fragment(s)"
make_k -s defconfig
if (( ${#fragments[@]} )); then
    (cd "$KERNEL_BUILD" && "$KERNEL_SRC/scripts/kconfig/merge_config.sh" \
        -m -O "$KERNEL_BUILD" .config "${fragments[@]}")
    make_k -s olddefconfig
    # merge_config.sh only warns; fail if a requested symbol did not stick.
    for f in "${fragments[@]}"; do
        while IFS= read -r line; do
            [[ $line =~ ^(CONFIG_[A-Za-z0-9_]+)= ]] || continue
            grep -qxF "$line" "$KERNEL_BUILD/.config" \
                || { echo "config not applied: $line ($f)" >&2; exit 1; }
        done < "$f"
    done
fi

# --- build -------------------------------------------------------------------
log "building Image, dtbs, modules with $JOBS jobs"
make_k Image dtbs modules

# --- collect -----------------------------------------------------------------
log "collecting output in $KERNEL_OUT"
rm -rf "$KERNEL_OUT"
mkdir -p "$KERNEL_OUT"
cp "$KERNEL_BUILD/arch/arm64/boot/Image" "$KERNEL_OUT/"
cp "$KERNEL_BUILD/arch/arm64/boot/dts/nvidia/$DTB_NAME.dtb" "$KERNEL_OUT/"
cp "$KERNEL_BUILD/.config" "$KERNEL_OUT/config"
make_k -s INSTALL_MOD_PATH="$KERNEL_OUT/modules" INSTALL_MOD_STRIP=1 modules_install
release=$(cat "$KERNEL_BUILD/include/config/kernel.release")
{
    echo "tag=$KERNEL_TAG"
    echo "release=$release"
    echo "patches=${#patches[@]}"
    echo "fragments=${*:-none}"
    echo "repo=$(git -C "$REPO_DIR" describe --always --dirty)"
} > "$KERNEL_OUT/VERSION"

log "done: $release"
ls -l "$KERNEL_OUT"
