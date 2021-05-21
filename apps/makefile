SRC_DIR := ./receiver

# Most likely want to override these when calling `make image`
IMAGE_REG ?= ghcr.io
IMAGE_REPO ?= benc-uk/dapr-gateway-experiment
IMAGE_TAG ?= latest
IMAGE_PREFIX := $(IMAGE_REG)/$(IMAGE_REPO)

.PHONY: help image-sender image-receiver push-sender push-receiver
.DEFAULT_GOAL := help

help: ## 💬 This help message :)
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

run-sender: ## 🏃‍ Run sender locally using Go
	go run ./sender/main.go

run-receiver: ## 🏃‍ Run receiver locally using Go
	go run ./receiver/main.go

image-sender: ## 📦 Build sender container image from Dockerfile
	docker build --file ./build/Dockerfile \
	--build-arg SRC_DIR="./sender" \
	--tag $(IMAGE_PREFIX)/sender:$(IMAGE_TAG) . 

image-receiver: ## 📦 Build receiver container image from Dockerfile
	docker build --file ./build/Dockerfile \
	--build-arg SRC_DIR="./receiver" \
	--tag $(IMAGE_PREFIX)/receiver:$(IMAGE_TAG) . 

push-sender: ## 📤 Push sender container image to registry
	docker push $(IMAGE_PREFIX)/sender:$(IMAGE_TAG)

push-receiver: ## 📤 Push receiver container image to registry
	docker push $(IMAGE_PREFIX)/receiver:$(IMAGE_TAG)