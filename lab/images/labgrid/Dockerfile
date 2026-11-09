# labgrid coordinator + exporter. Same labgrid version as the dev container.
FROM debian:trixie-slim
ARG LABGRID_VERSION=26.0.1
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-venv ser2net openssh-client \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir "labgrid==${LABGRID_VERSION}"
ENV PATH=/opt/venv/bin:$PATH
