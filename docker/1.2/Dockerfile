# syntax = docker/dockerfile:1.2

# ---
# NOTE: Use Alpine 3.12 as newer version present a performance regression
# Ref: https://github.com/crystal-lang/distribution-scripts/pull/127#issuecomment-920489700
FROM alpine:3.12 AS base

# ---
# 1. Upgrade system and installed dependencies for security patches
RUN --mount=type=cache,target=/var/cache/apk \
    set -eux; \
    apk upgrade

# ---
# 2. Install Crystal and dependencies
#
# TODO: combine tools and compiler layers
# TODO: validate Crystal package SHA256
# TODO: detect arch other than x86_64
# TODO: use latest version of Crystal
RUN --mount=type=cache,target=/var/cache/apk \
    set -eux; \
    apk add --no-cache \
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

RUN set -eux; \
    export CRYSTAL_VERSION=1.1.1; \
    cd /tmp; \
    { \
        curl --fail -Lo crystal.tar.gz https://github.com/crystal-lang/crystal/releases/download/${CRYSTAL_VERSION}/crystal-${CRYSTAL_VERSION}-1-linux-x86_64.tar.gz; \
        tar -xf crystal.tar.gz; \
        rm crystal-${CRYSTAL_VERSION}-1/lib/crystal/lib/libgc.a; \
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
# 3. TODO: Install additional packages

# ---
# 4. TODO: Setup non-root user (fixuid)
