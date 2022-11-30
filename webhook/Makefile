
.PHONY=build tmpdir install

ROOT:=$(shell pwd)
TMPDIR:=${ROOT}/.tmp

SERVICE_NAME=spoofed-webhook
IMAGE_NAME?=spoofed-webhook:internal
build:
	docker build --tag ${IMAGE_NAME} .

tmpdir:
	mkdir -p ${TMPDIR}

tmpdir.clean:
	rm -rf ${TMPDIR}


install: tmpdir.clean tmpdir
	./scripts/generate_cert.sh ${TMPDIR} ${SERVICE_NAME}
	./scripts/create_resources.sh ${TMPDIR} ${SERVICE_NAME}

