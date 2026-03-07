SHELL := /bin/bash

IMAGE_OS := ubuntu

LOG_DIR := logs
LOG_FILE := $(LOG_DIR)/build-dev-$(shell date +%Y%m%d-%H%M%S).log

build-dev:
	@mkdir -p $(LOG_DIR)
	@echo "Building digiKam dev environment (multi-stage, fully inlined).."
	@echo "Log file: $(LOG_FILE)"
	@podman build --tag digikam-dev --file "${IMAGE_OS}-dev.Containerfile" . 2>&1 | tee $(LOG_FILE)
