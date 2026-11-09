# Small Debian image shared by dnsmasq, iperf3-server and rootfs-helper.
FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        dnsmasq-base iperf3 python3 tar zstd rsync \
    && rm -rf /var/lib/apt/lists/*
