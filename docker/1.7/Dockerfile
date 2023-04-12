# syntax=docker/dockerfile:1.3

# ---
# Stages:
#
# stage0: use build platform and existing compiler to cross-compile for target
# stage1: link cross-compiled objects into executables on the target platform
# stage2: prepare directory structure, source code and final executables
# stage3: copy over artifacts and development utilities and dependencies

# ---
# stage0: bootstrap Crystal using Alpine's build of Crystal
FROM --platform=$BUILDPLATFORM alpine:3.17.2 AS stage0

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
        llvm14-dev \
        make \
        shards \
        yaml-dev \
    ;

# download and compile Crystal source for target platform
RUN set -eux -o pipefail; \
    cd /tmp; \
    export \
        CRYSTAL_VERSION=1.7.3 \
        CRYSTAL_SHA256=3ad94dd2835a58af8dabf18d6cdf3791eb49cdfc6fdc6fd6a4e59abf0e860a6f \
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
        SHARDS_VERSION=0.17.3 \
        SHARDS_SHA256=6512ff51bd69057f4da4783eb6b14c29d9a88b97d35985356d1dc644a08424c7 \
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
FROM alpine:3.17.2 AS stage1

# install dependencies needed for linking
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    set -eux; \
    apk add \
        g++ \
        gc-dev \
        gcc \
        git \
        libevent-static \
        libxml2-static \
        llvm14-dev \
        llvm14-static \
        make \
        musl-dev \
        pcre-dev \
        pcre2-dev \
        yaml-static \
        zlib-static \
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
FROM alpine:3.17.2 AS stage2

# combine source code and final binaries from previous stages
COPY --from=stage0 /tmp/crystal/src /usr/local/share/crystal/src
COPY --from=stage0 /usr/local/share/man /usr/local/share/man
COPY --from=stage1 /tmp/usr/local/bin /usr/local/bin

# ---
# stage3: final image
FROM alpine:3.17.2 AS stage3

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
        gcc \
        git \
        libevent-static \
        musl-dev \
        openssl-dev \
        openssl-libs-static \
        pcre-dev \
        pcre2-dev \
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
        export FIXUID_VERSION=0.5.1; \
        case "$(arch)" in \
        x86_64) \
            export \
                FIXUID_ARCH=amd64 \
                FIXUID_SHA256=1077e7af13596e6e3902230d7260290fe21b2ee4fffcea1eb548e5c465a34800 \
            ; \
            ;; \
        aarch64) \
            export \
                FIXUID_ARCH=arm64 \
                FIXUID_SHA256=7993a03876f5151c450e68a49706ef4c80d6b0ab755679eb47282df7f162fd82 \
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
        export OVERMIND_VERSION=2.4.0; \
        case "$(arch)" in \
        x86_64) \
            export \
                OVERMIND_ARCH=amd64 \
                OVERMIND_SHA256=1f7cac289b550a71bebf4a29139e58831b39003d9831be59eed3e39a9097311c \
            ; \
            ;; \
        aarch64) \
            export \
                OVERMIND_ARCH=arm64 \
                OVERMIND_SHA256=94a3e8393bd718ae9ec1b6cc21740bffa52da20710eaf020a7aa679cdc926104 \
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
        export WATCHEXEC_VERSION=1.21.1; \
        case "$(arch)" in \
        x86_64) \
            export \
                WATCHEXEC_ARCH=x86_64 \
                WATCHEXEC_SHA256=807c05bf02dbe77b19e2acbfa9860ccbfcc0a3972fbf984f5b664b1ba5ef4f98 \
            ; \
            ;; \
        aarch64) \
            export \
                WATCHEXEC_ARCH=aarch64 \
                WATCHEXEC_SHA256=ebd3c97178eda2806e0e02149503269179cec09b95bdd2700de10a4eea54852b \
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
