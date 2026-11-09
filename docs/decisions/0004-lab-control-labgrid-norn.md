# 0004 – Board control via labgrid and Norn

Status: accepted (2026-11-09)

**Decision:** labgrid (coordinator + exporter) runs in Docker Compose. Power and
buttons are driven by Norn (Waveshare Pico Relay B, labgrid-compatible REST API),
running natively on the host. Console via a USB-UART adapter on the debug UART.

**Consequences:** Every boot has a hard timeout followed by a power cycle.
