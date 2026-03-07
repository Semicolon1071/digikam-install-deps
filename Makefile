SHELL := /bin/bash

IMAGE_OS := ubuntu

LOG_DIR := logs
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
LOG_FILE := $(LOG_DIR)/build-dev-$(TIMESTAMP).log
STATS_FILE := $(LOG_DIR)/resource-stats-$(TIMESTAMP).csv

build-dev:
	@mkdir -p $(LOG_DIR)
	@echo "Building digiKam dev environment (multi-stage, fully inlined).."
	@echo "Build log:    $(LOG_FILE)"
	@echo "Resource log: $(STATS_FILE)"
	@# Record CPU, memory, and disk I/O every 10 seconds in the background.
	@# The stats file is CSV and can be opened in any spreadsheet tool.
	@dstat --cpu --mem --disk --io --load --time --output "$(STATS_FILE)" 10 > /dev/null 2>&1 & \
		DSTAT_PID=$$!; \
		podman build --tag digikam-dev --file "${IMAGE_OS}-dev.Containerfile" . 2>&1 | tee "$(LOG_FILE)"; \
		BUILD_EXIT=$$?; \
		kill $$DSTAT_PID 2>/dev/null; \
		echo "Resource stats saved to $(STATS_FILE)"; \
		exit $$BUILD_EXIT
