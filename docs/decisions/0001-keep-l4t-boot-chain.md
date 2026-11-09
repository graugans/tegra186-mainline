# 0001 – Keep the L4T boot chain

Status: accepted (2026-11-09)

**Context:** MB1/MB2/BPMP firmware and CBoot are signed/proprietary; replacing
them is high risk and not needed to run a mainline kernel.

**Decision:** MB1/MB2/BPMP blobs and CBoot stay unchanged. The L4T U-Boot stays;
it may be patched in phase 3. Bootloader changes go to slot B only.

**Consequences:** The mainline kernel must work against the L4T BPMP firmware ABI.
