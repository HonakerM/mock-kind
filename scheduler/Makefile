
.PHONY=build
IMAGE_NAME?=spoofed-scheduler:internal
build:
	docker build --tag ${IMAGE_NAME} .

deploy.second:
	kubectl apply -f ./manifests