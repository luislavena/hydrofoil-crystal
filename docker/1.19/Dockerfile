# syntax=docker/dockerfile:1

# ---
# Stages:
#
# stage0: use build platform and existing compiler to cross-compile for target
# stage1: link cross-compiled objects into executables on the target platform
# stage2: prepare directory structure, source code and final executables
# stage3: copy over artifacts and development utilities and dependencies

# ---
# stage0: bootstrap Crystal using Alpine's build of Crystal
ARG ALPINE_VERSION=3.23.2
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS stage0

# expose the target architecture to be used in cross-compilation
ARG TARGETARCH

# install dependencies needed for cross-compilation of Crystal and Shards
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    set -eux; \
    apk add \
        crystal \
        curl \
        g++ \
        git \
        llvm21-dev \
        make \
        shards \
        yaml-dev \
    ;

# download and compile Crystal source for target platform
RUN set -eux -o pipefail; \
    cd /tmp; \
    export \
        CRYSTAL_VERSION=1.19.0 \
        CRYSTAL_SHA256=9b1bc649408a61721b98fd027cbc53d52e75a3ac0ae12f2a0d0324adb37e9464 \
    ; \
    { \
        curl --fail -Lo crystal.tar.gz https://github.com/crystal-lang/crystal/archive/refs/tags/${CRYSTAL_VERSION}.tar.gz; \
        echo "${CRYSTAL_SHA256} *crystal.tar.gz" | sha256sum -c - >/dev/null 2>&1; \
        tar -xf crystal.tar.gz; \
        rm crystal.tar.gz; \
        mv crystal-${CRYSTAL_VERSION} crystal; \
    }; \
    { \
        cd /tmp/crystal; \
        # prepare man page
        gzip -9 man/crystal.1; \
        mkdir -p /usr/local/share/man/man1; \
        cp -f man/*.1.gz /usr/local/share/man/man1/; \
        # build Compiler for target architecture
        mkdir -p .build; \
        make crystal release=1 static=1 target=$TARGETARCH-alpine-linux-musl | tail -1 | tee .build/crystal.sh; \
        rm -rf src/llvm/ext/llvm_ext.o; \
    }

# download and compile Shards source for target platform
RUN set -eux -o pipefail; \
    cd /tmp; \
    export \
        SHARDS_VERSION=0.20.0 \
        SHARDS_SHA256=8655b87761016409e4411056e350b24e7fe79eae3f227b3354b181a03f14d5da \
    ; \
    { \
        curl --fail -Lo shards.tar.gz https://github.com/crystal-lang/shards/archive/refs/tags/v${SHARDS_VERSION}.tar.gz; \
        echo "${SHARDS_SHA256} *shards.tar.gz" | sha256sum -c - >/dev/null 2>&1; \
        tar -xf shards.tar.gz; \
        rm shards.tar.gz; \
        mv shards-${SHARDS_VERSION} shards; \
    }; \
    { \
        cd /tmp/shards; \
        # prepare man pages
        gzip -9 man/shards.1 man/shard.yml.5; \
        mkdir -p /usr/local/share/man/man1 /usr/local/share/man/man5; \
        cp -f man/*.1.gz /usr/local/share/man/man1/; \
        cp -f man/*.5.gz /usr/local/share/man/man5/; \
        # build for target platform
        make bin/shards release=1 static=1 FLAGS="--cross-compile --target $TARGETARCH-alpine-linux-musl" | tail -1 | tee bin/shards.sh; \
    }

# ---
# stage1: link compiled objects on target platform
FROM alpine:${ALPINE_VERSION} AS stage1

# install dependencies needed for linking
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    set -eux; \
    apk add \
        g++ \
        gc-static \
        gcc \
        git \
        libxml2-static \
        llvm21-dev \
        llvm21-static \
        make \
        musl-dev \
        pcre2-static \
        yaml-static \
        zlib-static \
        zstd-static \
    ;

# copy build artifacts from stage0
COPY --from=stage0 /tmp/crystal/.build /tmp/crystal/.build
COPY --from=stage0 /tmp/crystal/Makefile /tmp/crystal/Makefile
COPY --from=stage0 /tmp/crystal/src/llvm/ext /tmp/crystal/src/llvm/ext
COPY --from=stage0 /tmp/shards/bin /tmp/shards/bin

# link objects to final binaries
RUN set -eux; \
    # compile LLVM extension and link the compiler
    { \
        cd /tmp/crystal; \
        mkdir -p spec/; \
        make llvm_ext; \
        sh -ex .build/crystal.sh; \
        # smoke test
        .build/crystal --version; \
        # copy final binary
        mkdir -p /tmp/usr/local/bin; \
        cp -f .build/crystal /tmp/usr/local/bin/; \
    }; \
    # compile shards
    { \
        cd /tmp/shards; \
        sh -ex bin/shards.sh; \
        # smoke test
        bin/shards --version; \
        # copy final binary
        mkdir -p /tmp/usr/local/bin; \
        cp -f bin/shards /tmp/usr/local/bin/; \
    }

# ---
# stage2: prepare binaries and code for final image
FROM alpine:${ALPINE_VERSION} AS stage2

# combine source code and final binaries from previous stages
COPY --from=stage0 /tmp/crystal/src /usr/local/share/crystal/src
COPY --from=stage0 /usr/local/share/man /usr/local/share/man
COPY --from=stage1 /tmp/usr/local/bin /usr/local/bin

# ---
# stage3: final image
FROM alpine:${ALPINE_VERSION} AS stage3

# upgrade system and installed dependencies for security patches
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    set -eux; \
    apk upgrade

# copy prepared structure from stage2
COPY --from=stage2 /usr/local /usr/local

# install dependencies and common packages
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    set -eux; \
    apk add \
        curl \
        gc-dev \
        gc-static \
        gcc \
        git \
        libevent-dev \
        libevent-static \
        musl-dev \
        openssl-dev \
        openssl-libs-static \
        pcre2-dev \
        pcre2-static \
        sqlite-dev \
        sqlite-static \
        tzdata \
        yaml-dev \
        yaml-static \
        zlib-dev \
        zlib-static \
    ; \
    # smoke tests
    [ "$(command -v crystal)" = '/usr/local/bin/crystal' ]; \
    [ "$(command -v shards)" = '/usr/local/bin/shards' ]; \
    crystal --version; \
    shards --version

# setup non-root user (fixuid)
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux -o pipefail; \
    # create non-root user & give passwordless sudo
    { \
        apk add sudo; \
        addgroup -g 1000 user; \
        adduser -u 1000 -G user -h /home/user -s /bin/sh -D user; \
        mkdir -p /etc/sudoers.d; \
        echo "user ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/user; \
        # cleanup backup copies
        rm /etc/group- /etc/passwd- /etc/shadow-; \
    }; \
    # Install fixuid
    { \
        cd /tmp; \
        export FIXUID_VERSION=0.6.0; \
        case "$(arch)" in \
        x86_64) \
            export \
                FIXUID_ARCH=amd64 \
                FIXUID_SHA256=8c47f64ec4eec60e79871796ea4097ead919f7fcdedace766da9510b78c5fa14 \
            ; \
            ;; \
        aarch64) \
            export \
                FIXUID_ARCH=arm64 \
                FIXUID_SHA256=827e0b480c38470b5defb84343be7bb4e85b9efcbf3780ac779374e8b040a969 \
            ; \
            ;; \
        esac; \
        wget -q -O fixuid.tar.gz https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-linux-${FIXUID_ARCH}.tar.gz; \
        echo "${FIXUID_SHA256} *fixuid.tar.gz" | sha256sum -c - >/dev/null 2>&1; \
        tar -xf fixuid.tar.gz; \
        mv fixuid /usr/local/bin/; \
        chmod u+s /usr/local/bin/fixuid; \
        rm fixuid.tar.gz; \
    }; \
    # Generate fixuid config
    mkdir -p /etc/fixuid; \
    { \
        echo "user: user"; \
        echo "group: user"; \
    } | tee /etc/fixuid/config.yml

# Adjust Overmind socket location
ENV OVERMIND_SOCKET=/tmp/overmind.sock

# Adjust ENTRYPOINT
ENTRYPOINT [ "/usr/local/bin/fixuid", "-q" ]
CMD [ "/bin/sh" ]

# install development utilities
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux; \
    cd /tmp; \
    # Overmind (needs tmux)
    { \
        export OVERMIND_VERSION=2.5.1; \
        case "$(arch)" in \
        x86_64) \
            export \
                OVERMIND_ARCH=amd64 \
                OVERMIND_SHA256=a17159b8e97d13f3679a4e8fbc9d4747f82d5af9f6d32597b72821378b5d0b6f \
            ; \
            ;; \
        aarch64) \
            export \
                OVERMIND_ARCH=arm64 \
                OVERMIND_SHA256=42cb6d79c8adcf4c68dfb2ddf09e63a0803b023af5b17d42e05ccbfa4b86bee2 \
            ; \
            ;; \
        esac; \
        apk add \
            tmux \
        ; \
        curl --fail -Lo overmind.gz https://github.com/DarthSim/overmind/releases/download/v${OVERMIND_VERSION}/overmind-v${OVERMIND_VERSION}-linux-${OVERMIND_ARCH}.gz; \
        echo "${OVERMIND_SHA256} *overmind.gz" | sha256sum -c - >/dev/null 2>&1; \
        gunzip overmind.gz; \
        chmod +x overmind; \
        mv overmind /usr/local/bin/; \
    }; \
    # Watchexec
    { \
        export WATCHEXEC_VERSION=2.2.1; \
        case "$(arch)" in \
        x86_64) \
            export \
                WATCHEXEC_ARCH=x86_64 \
                WATCHEXEC_SHA256=74651d6f450bca5436eee35b7828f1b97388d3b3976da313db36e3a91f7ada44 \
            ; \
            ;; \
        aarch64) \
            export \
                WATCHEXEC_ARCH=aarch64 \
                WATCHEXEC_SHA256=87ec2094f2e883a090cb4a72a073f9b44f4aba7f50481f068e175f993d15c581 \
            ; \
            ;; \
        esac; \
        curl --fail -Lo watchexec.tar.xz https://github.com/watchexec/watchexec/releases/download/v${WATCHEXEC_VERSION}/watchexec-${WATCHEXEC_VERSION}-${WATCHEXEC_ARCH}-unknown-linux-musl.tar.xz; \
        echo "${WATCHEXEC_SHA256} *watchexec.tar.xz" | sha256sum -c - >/dev/null 2>&1; \
        tar -xf watchexec.tar.xz; \
        mv watchexec-${WATCHEXEC_VERSION}-${WATCHEXEC_ARCH}-unknown-linux-musl/watchexec /usr/local/bin/; \
        rm -rf watchexec.tar.xz watchexec-${WATCHEXEC_VERSION}-${WATCHEXEC_ARCH}-unknown-linux-musl; \
    }; \
    # smoke tests
    [ "$(command -v overmind)" = '/usr/local/bin/overmind' ]; \
    [ "$(command -v watchexec)" = '/usr/local/bin/watchexec' ]; \
    overmind --version; \
    watchexec --version
