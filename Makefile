SHA ?= $(shell git describe --match=none --always --abbrev=8)
TAG ?= $(shell git describe --tag --always)

GOLANG_IMAGE ?= golang:1.16

COMMON_ARGS := -f ./Dockerfile --build-arg GOLANG_IMAGE=$(GOLANG_IMAGE) --build-arg SHA=$(SHA) --build-arg TAG=$(TAG) .

export DOCKER_BUILDKIT := 1

all: enforce build test image

enforce:
	@go run main.go enforce

.PHONY: build
build:
	@docker build \
		-t conform/$@:$(TAG) \
		--target=$@ \
		$(COMMON_ARGS)
	@docker run --rm -v $(PWD)/build:/build conform/$@:$(TAG) cp /conform-linux-amd64 /build
	@docker run --rm -v $(PWD)/build:/build conform/$@:$(TAG) cp /conform-darwin-amd64 /build

test:
	@docker build \
		--network=host \
		-t conform/$@:$(TAG) \
		--target=$@ \
		$(COMMON_ARGS)
	@docker run --rm -v $(PWD)/build:/build conform/$@:$(TAG) cp /coverage.txt /build

image: build
	@docker build \
		--network=host \
		-t autonomy/conform:$(TAG) \
		--target=$@ \
		$(COMMON_ARGS)

.PHONY: login
login:
	@docker login --username "$(DOCKER_USERNAME)" --password "$(DOCKER_PASSWORD)"

push: image
	@docker tag autonomy/conform:$(TAG) autonomy/conform:latest
	@docker push autonomy/conform:$(TAG)
	@docker push autonomy/conform:latest

deps:
	@GO111MODULE=on CGO_ENABLED=0 go get -u github.com/autonomy/gitmeta
	@GO111MODULE=on CGO_ENABLED=0 go get -u github.com/talos-systems/conform

clean:
	go clean -modcache
	rm -rf build vendor
