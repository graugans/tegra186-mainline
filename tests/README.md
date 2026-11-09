# tests

pytest tests, run **in the dev container** with the labgrid pytest plugin.
They reach the board over the UART (`ShellDriver`) and SSH (`SSHDriver`);
nothing runs pytest on the board. See
[decision 0007](../docs/decisions/0007-pytest-labgrid-tests.md).

Each test declares its requirements as pytest markers (kernel version, config
symbols, bootargs, userspace tools, lab services, timeout, thresholds); tests
the current build cannot satisfy are deselected at collection time.
