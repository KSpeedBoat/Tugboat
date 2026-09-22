# Tugboat - Automated Operations Platform
# Usage: make <target>

BINARY_SERVER  = tugboat-server
BINARY_AGENT   = tugboat-agent
BINARY_CLI     = tugboat-cli
BUILD_DIR      = ./dist

.PHONY: all build-server build-agent build-cli clean test

all: build-server build-agent build-cli

build-server:
	go build -o $(BUILD_DIR)/$(BINARY_SERVER) ./cmd/tugboat-server

build-agent:
	go build -o $(BUILD_DIR)/$(BINARY_AGENT) ./cmd/tugboat-agent

build-cli:
	go build -o $(BUILD_DIR)/$(BINARY_CLI) ./cmd/tugboat-cli

test:
	go test ./...

clean:
	rm -rf $(BUILD_DIR)
