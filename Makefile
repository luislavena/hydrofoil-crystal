VERSION ?= 1.17
REGISTRY ?= ghcr.io

DOCKERFILE := docker/${VERSION}/Dockerfile
IMAGE_NAME := ${REGISTRY}/luislavena/hydrofoil-crystal

.PHONY: test
test: build
	dgoss run ${IMAGE_NAME}:${VERSION} sleep infinity

.PHONY: build
build: ${DOCKERFILE}
	docker build --progress=plain -t ${IMAGE_NAME}:${VERSION} -f ${DOCKERFILE} .

.PHONY: console
console: build
	docker run -it --rm -v .:/code -w /code ${IMAGE_NAME}:${VERSION} -- sh -i
