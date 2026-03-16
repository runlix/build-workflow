# Builder tag from VERSION.json builder.tag (e.g., "bookworm-slim")
ARG BUILDER_TAG=bookworm-slim
# Base tag (variant-arch) from VERSION.json base.tag (e.g., "release-2025.12.29.1-linux-amd64-latest")
ARG BASE_TAG=release-2025.12.29.1-linux-amd64-latest
# Selected digests (build script will set based on target configuration)
# Default to empty string - build script will always provide valid digests
# If empty, FROM will fail (which is desired to enforce digest pinning)
ARG BUILDER_DIGEST=""
ARG BASE_DIGEST=""
# Package URL from VERSION.json package_url
ARG PACKAGE_URL=""
# par2turbo version (can be added to VERSION.json later if needed)
ARG PAR2TURBO_VERSION=1.3.0
# unrar version - source available at https://www.rarlab.com/rar_add.htm
ARG UNRAR_VERSION=7.2.3

# STAGE 1 — fetch SABnzbd source
# Build script will pass BUILDER_TAG and BUILDER_DIGEST from VERSION.json
# Format: debian:bookworm-slim@sha256:digest (when digest provided)
FROM docker.io/library/debian:${BUILDER_TAG}@${BUILDER_DIGEST} AS fetch

# Redeclare ARG in this stage so it's available for use in RUN commands
ARG PACKAGE_URL

WORKDIR /app

# Use BuildKit cache mounts to persist apt cache between builds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/sabnzbd \
 && curl -L -f "${PACKAGE_URL}" -o sabnzbd.tar.gz \
 && tar -xzf sabnzbd.tar.gz -C /app/sabnzbd --strip-components=1 \
 && chmod -R u=rwX,go=rX /app/sabnzbd \
 && rm sabnzbd.tar.gz

# STAGE 2 — build par2turbo, unrar and install Python dependencies
# Build script will pass BUILDER_TAG and BUILDER_DIGEST from VERSION.json
FROM docker.io/library/debian:${BUILDER_TAG}@${BUILDER_DIGEST} AS sabnzbd-deps

ARG PAR2TURBO_VERSION
ARG UNRAR_VERSION

# Use BuildKit cache mounts to persist apt cache between builds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-minimal \
    python3-pip \
    python3-dev \
    build-essential \
    autoconf \
    automake \
    libtool \
    curl \
    tar \
    gcc \
    g++ \
    make \
    libffi-dev \
    libssl-dev \
    cargo \
    rustc \
    p7zip-full \
    util-linux \
&& rm -rf /var/lib/apt/lists/*

# Build par2turbo
WORKDIR /tmp
RUN curl -fsSL "https://github.com/animetosho/par2cmdline-turbo/archive/refs/tags/v${PAR2TURBO_VERSION}.tar.gz" | tar xzf - -C /tmp --strip-components=1 \
 && aclocal \
 && automake --add-missing \
 && autoconf \
 && ./configure \
 && make \
 && make install

# Build unrar from source
# Source available at https://www.rarlab.com/rar_add.htm
WORKDIR /tmp
RUN curl -fsSL "https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz" -o unrar.tar.gz \
 && tar -xzf unrar.tar.gz \
 && cd unrar \
 && make -f makefile \
 && cp unrar /usr/local/bin/unrar \
 && chmod +x /usr/local/bin/unrar \
 && cd /tmp \
 && rm -rf unrar unrar.tar.gz

# Install Python packages from SABnzbd requirements.txt
# Copy requirements.txt from fetch stage
COPY --from=fetch /app/sabnzbd/requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

# #region agent log - Debug: Check Python3 library dependencies
RUN ldd /usr/bin/python3 > /tmp/python3_deps.txt 2>&1 || true && \
    echo "=== Python3 library dependencies ===" && \
    cat /tmp/python3_deps.txt && \
    echo "=== Missing libraries check ===" && \
    (ldd /usr/bin/python3 2>&1 | grep "not found" || echo "No missing libraries found") && \
    echo "=== All Python3 dependencies ===" && \
    ldd /usr/bin/python3 2>&1 | grep "=>" | awk '{print $3}' | sort -u > /tmp/python3_libs.txt && \
    cat /tmp/python3_libs.txt
# #endregion agent log

# STAGE 3 — distroless final image
# Build script will pass BASE_TAG (from VERSION.json base.tag) and BASE_DIGEST
# Format: ghcr.io/runlix/distroless-runtime:release-2025.12.29.1-linux-amd64-latest@sha256:digest (when digest provided)
FROM ghcr.io/runlix/distroless-runtime:${BASE_TAG}@${BASE_DIGEST}

# Hardcoded for amd64 - no conditionals needed!
ARG LIB_DIR=x86_64-linux-gnu
ARG LD_SO=ld-linux-x86-64.so.2

# Copy SABnzbd source
COPY --from=fetch /app/sabnzbd /app/sabnzbd

# Copy par2 binaries
COPY --from=sabnzbd-deps /usr/local/bin/par2* /usr/local/bin/

# Copy extraction and priority utilities
COPY --from=sabnzbd-deps /usr/local/bin/unrar /usr/local/bin/unrar
COPY --from=sabnzbd-deps /usr/bin/7za /usr/bin/7za
COPY --from=sabnzbd-deps /usr/bin/nice /usr/bin/nice
COPY --from=sabnzbd-deps /usr/bin/ionice /usr/bin/ionice

# Copy Python runtime
COPY --from=sabnzbd-deps /usr/bin/python3 /usr/bin/python3
COPY --from=sabnzbd-deps /usr/bin/python3.11 /usr/bin/python3.11

# Copy Python shared libraries
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libpython3.11.so.* /usr/lib/${LIB_DIR}/

# Copy Python site-packages (installed packages)
# Debian bookworm uses Python 3.11
COPY --from=sabnzbd-deps /usr/local/lib/python3.11/dist-packages /usr/local/lib/python3.11/dist-packages

# Copy Python standard library
COPY --from=sabnzbd-deps /usr/lib/python3.11 /usr/lib/python3.11

# #region agent log - Debug: Copy Python3 dependency libraries
# Copy all Python3 runtime dependencies identified in debug stage
COPY --from=sabnzbd-deps /tmp/python3_libs.txt /tmp/python3_libs.txt
# Copy common Python runtime libraries (required by Python3)
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libexpat.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libbz2.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/liblzma.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libz.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libreadline.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libncurses.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libtinfo.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libsqlite3.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libgdbm.so.* /usr/lib/${LIB_DIR}/
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libgdbm_compat.so.* /usr/lib/${LIB_DIR}/
# #endregion agent log

# Copy shared libraries for extraction and priority utilities
# C++ standard library (required by unrar and 7za)
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libstdc++.so.* /usr/lib/${LIB_DIR}/
# GCC support library (required by C++ binaries)
COPY --from=sabnzbd-deps /usr/lib/${LIB_DIR}/libgcc_s.so.* /usr/lib/${LIB_DIR}/

WORKDIR /app/sabnzbd
USER 65532:65532
ENTRYPOINT ["/usr/bin/python3", "-OO", "SABnzbd.py", "--browser", "0", "--server", "0.0.0.0:8080", "--config-file", "/config"]
