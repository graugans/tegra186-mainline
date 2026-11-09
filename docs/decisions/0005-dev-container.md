# 0005 – Dev container for toolchain and agent

Status: accepted (2026-11-09)

**Decision:** Cross toolchain, ccache, dtc, u-boot-tools, kas, labgrid client and
Claude Code live in a dev container without root rights on shared paths.
GitHub is used for hosting only, no CI/CD. Meta-tegra is used only as the
source for CBoot sources (L4T R32.7.x).
