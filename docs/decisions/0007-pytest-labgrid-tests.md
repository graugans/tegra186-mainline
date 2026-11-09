# 0007 – Tests with pytest + labgrid, run from the dev container

Status: accepted (2026-11-09)

**Context:** The test approach follows the Renesas talk "Embedded Linux Kernel
Testing With Pytest" (Castro/Paterson, OSS EU 2026,
[slides](https://hosted-files.sched.co/osselceu2026/7f/OSS-EU_2026_Embedded-Linux-Kernel-Testing-With-Pytest.pdf)).
There, pytest markers carry each test's requirements and pytest runs on the
target under LAVA. We have one board, labgrid instead of LAVA, no CI, and a
disposable NFS rootfs.

**Decision:**
- pytest runs in the **dev container**, not on the board. The labgrid pytest
  plugin (`--lg-env`, `target` fixture) controls the board: Norn power via
  `NetworkPowerDriver`, console via `SerialDriver`/`ShellDriver`, commands via
  `SSHDriver`. A labgrid strategy drives off → U-Boot (PXE) → Linux shell with
  hard timeouts.
- Tests carry their contract as **pytest markers**, as in the talk: minimum
  kernel version, required config symbols, bootargs, userspace tools, lab
  services (e.g. `iperf3-server`), timeout and measurement thresholds.
  `pytest_collection_modifyitems` deselects tests whose contract the current
  build (`/work/kernel-out/config`, `VERSION`) does not meet.
- Results are keyed by board, `uname -r`, test, config and run ID and stored
  in `logs/<run-id>/`. A test fails on timeout, crash/panic on the UART,
  missing or out-of-range measurements.

**Consequences:**
- The NFS rootfs stays disposable; nothing is stored on the board.
- A kernel panic or hang ends the test, not the test runner; the UART log is
  captured on the host side.
- The rootfs needs only the tools under test plus sshd, no pytest/Python.
- pytest and the labgrid plugin are already in the dev container venv.
