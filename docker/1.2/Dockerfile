# syntax = docker/dockerfile:1.2

# ---
# 1. Use Alpine as base
#
# NOTE: Use Alpine 3.12 as newer version present a performance regression
# Ref: https://github.com/crystal-lang/distribution-scripts/pull/127#issuecomment-920489700
FROM alpine:3.12 AS base

# ---
# 2. Upgrade system and installed dependencies for security patches
RUN --mount=type=cache,target=/var/cache/apk \
    set -eux; \
    apk upgrade

# ---
# 3. Install Crystal dependencies
RUN --mount=type=cache,target=/var/cache/apk \
    set -eux; \
    apk add \
        curl \
        gc-dev \
        gcc \
        git \
        libevent-static \
        musl-dev \
        openssl-dev \
        openssl-libs-static \
        pcre-dev \
        yaml-static \
        zlib-dev \
        zlib-static \
    ;

# ---
# 4. Download and extract Crystal
#
# TODO: detect arch other than x86_64
RUN --mount=type=cache,target=/tmp \
    set -eux; \
    export \
        CRYSTAL_VERSION=1.2.1 \
        CRYSTAL_SHA256=66e51bd2e72363858b5a41755396158d6aaf76b177a51741e4ab2df3323f0ff4; \
    cd /tmp; \
    { \
        curl --fail -Lo crystal.tar.gz https://github.com/crystal-lang/crystal/releases/download/${CRYSTAL_VERSION}/crystal-${CRYSTAL_VERSION}-1-linux-x86_64.tar.gz; \
        echo "${CRYSTAL_SHA256} *crystal.tar.gz" | sha256sum -c - >/dev/null 2>&1; \
        tar -xf crystal.tar.gz; \
        rm crystal-${CRYSTAL_VERSION}-1/lib/crystal/libgc.a; \
        mv crystal-${CRYSTAL_VERSION}-1 /usr/local/crystal; \
        rm crystal.tar.gz; \
    }; \
    # smoke test
    PATH=/usr/local/crystal/bin:$PATH; \
    [ "$(command -v crystal)" = '/usr/local/crystal/bin/crystal' ]; \
    [ "$(command -v shards)" = '/usr/local/crystal/bin/shards' ]; \
    crystal --version; \
    shards --version

ENV PATH /usr/local/crystal/bin:$PATH

# ---
# 5. TODO: Install development utilities

# ---
# 6. TODO: Setup non-root user (fixuid)
