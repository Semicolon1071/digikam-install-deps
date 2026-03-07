SHELL := /bin/bash

IMAGE_OS := ubuntu

build-dev:
	@echo "Building digiKam dev environment (multi-stage, fully inlined).."
	@podman build --tag digikam-dev --file "${IMAGE_OS}-dev.Containerfile" .
