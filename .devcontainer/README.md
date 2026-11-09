# .devcontainer

Dockerfile-based dev container on Debian 13 "trixie" (latest stable).

Contains: Yocto host packages, aarch64 cross toolchain, ccache, dtc,
u-boot-tools, kas, labgrid client, Claude Code CLI and VS Code extensions.

Mounts:
- repo at the same path as on the host
- `../tegra186-work` → `/work` (ccache, kernel tree, Yocto downloads/sstate/build)
- `~/.claude` → `/home/dev/.claude` (Claude Code login and project memory)

Runs with `--network=host`. `/srv/tftp` and the UART are added once the lab
network and USB setup are done (see top-level README).
