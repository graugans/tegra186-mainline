# Dev container for tegra186-mainline.
# Base: latest Debian stable (13 "trixie").
FROM debian:trixie

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG KAS_VERSION=5.5
ARG LABGRID_VERSION=26.0.1

ENV DEBIAN_FRONTEND=noninteractive

# Yocto host requirements (Debian list from the Yocto ref-manual, wrynose),
# kernel cross build, bootloader/DT tools and lab/debug helpers.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential chrpath cpio debianutils diffstat file gawk gcc git \
        iputils-ping libacl1 lz4 locales python3 python3-git python3-jinja2 \
        python3-pexpect python3-pip python3-subunit python3-venv socat \
        texinfo unzip wget xz-utils zstd \
        gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
        bc bison flex libssl-dev libelf-dev libncurses-dev kmod rsync dwarves \
        ccache device-tree-compiler u-boot-tools \
        ca-certificates curl gnupg less vim-tiny nano sudo bash-completion \
        openssh-client iproute2 procps tftp-hpa picocom jq shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Yocto needs a UTF-8 locale.
RUN sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# kas and labgrid client in a dedicated venv (Debian blocks pip into system python).
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir \
        "kas==${KAS_VERSION}" "labgrid==${LABGRID_VERSION}" \
    && for b in /opt/venv/bin/kas* /opt/venv/bin/labgrid-*; do \
           ln -s "$b" /usr/local/bin/; done
# Symlinks above survive login shells (/etc/profile resets PATH).
ENV PATH=/opt/venv/bin:$PATH

# Unprivileged user (bitbake refuses to run as root). sudo stays container-local.
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && mkdir -p /work && chown ${USERNAME}:${USERNAME} /work

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Claude Code CLI (native installer, lands in ~/.local/bin).
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/${USERNAME}/.local/bin:$PATH

# Build caches and work trees live on the /work bind mount.
ENV CCACHE_DIR=/work/ccache \
    KAS_WORK_DIR=/work/yocto \
    DL_DIR=/work/yocto/downloads \
    SSTATE_DIR=/work/yocto/sstate-cache \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu-
