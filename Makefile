VERSION ?= 1.22
REGISTRY ?= ghcr.io

DOCKERFILE := docker/${VERSION}/Dockerfile
IMAGE_NAME := ${REGISTRY}/luislavena/hydrofoil-crystal

# dgoss copies goss into the container, so it must be a Linux binary (not the host one on macOS)
GOSS_VERSION ?= v0.4.9
GOSS_ARCH := $(shell docker version --format '{{.Server.Arch}}')
GOSS_PATH ?= .cache/goss-${GOSS_VERSION}-linux-${GOSS_ARCH}
GOSS_URL := https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-${GOSS_ARCH}

.PHONY: test
test: build ${GOSS_PATH}
	GOSS_PATH=${GOSS_PATH} dgoss run ${IMAGE_NAME}:${VERSION} sleep infinity

${GOSS_PATH}:
	mkdir -p $(@D)
	curl -fsSL -o $@.tmp ${GOSS_URL}
	test "$$(curl -fsSL ${GOSS_URL}.sha256 | cut -d' ' -f1)" = "$$(sha256sum $@.tmp | cut -d' ' -f1)"
	chmod +x $@.tmp
	mv $@.tmp $@

.PHONY: build
build: ${DOCKERFILE}
	docker build --progress=plain -t ${IMAGE_NAME}:${VERSION} -f ${DOCKERFILE} .

.PHONY: console
console: build
	docker run -it --rm -v .:/code -w /code ${IMAGE_NAME}:${VERSION} -- sh -i
