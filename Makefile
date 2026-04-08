.PHONY: setup build run stop status clean test-template help

IMAGE_TAG        ?= claude-code-devcontainer:latest
CONTAINER_NAME   ?= claude-code-env

# macOS is always Apple Silicon (arm64); WSL2 runs on x86_64.
# Explicit --platform prevents accidental amd64 builds that would require Rosetta.
PLATFORM_macos   := linux/arm64
PLATFORM_wsl2    := linux/amd64

# Detect OS once; used by all targets that branch per platform
# $(shell ...) is used instead of != for compatibility with GNU Make 3.81 (ships with macOS)
_OS := $(shell bash -c 'source scripts/detect-os.sh && echo $$DETECTED_OS')

## setup    Detect OS and install prerequisites
setup:
	@bash setup.sh

## build    Build the container image (apple/container on macOS, podman on WSL2)
build:
	@echo "Building on: $(_OS)"
	@if [ "$(_OS)" = "macos" ]; then \
		container system property set build.rosetta false 2>/dev/null || true; \
		container build \
			--platform $(PLATFORM_macos) \
			--file .devcontainer/Containerfile \
			--tag $(IMAGE_TAG) \
			--build-arg USERNAME=claude \
			--build-arg USER_UID=1000 \
			--build-arg USER_GID=1000 \
			--build-arg TARGETPLATFORM=$(PLATFORM_macos) \
			.; \
	else \
		podman build \
			--platform $(PLATFORM_wsl2) \
			--file .devcontainer/Containerfile \
			--tag $(IMAGE_TAG) \
			--build-arg USERNAME=claude \
			--build-arg USER_UID=1000 \
			--build-arg USER_GID=1000 \
			--build-arg TARGETPLATFORM=$(PLATFORM_wsl2) \
			.; \
	fi

## run      (macOS only) Start the container so VSCode can attach to it
run:
	@if [ "$(_OS)" != "macos" ]; then \
		echo "WSL2: open this folder in VS Code and choose 'Reopen in Container'."; \
	else \
		CLAUDE_CONTAINER_NAME=$(CONTAINER_NAME) \
		CLAUDE_IMAGE_TAG=$(IMAGE_TAG) \
		bash scripts/macos/run.sh; \
	fi

## stop     (macOS only) Stop the running container
stop:
	@if [ "$(_OS)" = "macos" ]; then \
		container stop $(CONTAINER_NAME) 2>/dev/null && echo "Stopped $(CONTAINER_NAME)" || true; \
	fi

## status   Show runtime and container state
status:
	@echo "OS: $(_OS)"
	@if [ "$(_OS)" = "macos" ]; then \
		container --version 2>/dev/null || echo "apple/container: not found"; \
		container inspect $(CONTAINER_NAME) \
			--format "Container: {{.Name}}  Status: {{.State.Status}}" 2>/dev/null \
			|| echo "Container: $(CONTAINER_NAME) — not running (run: make run)"; \
	else \
		podman --version 2>/dev/null || echo "podman: not found"; \
	fi

## clean    Remove the container image (and stop the container on macOS)
clean:
	@if [ "$(_OS)" = "macos" ]; then \
		container stop $(CONTAINER_NAME) 2>/dev/null || true; \
		container rm   $(CONTAINER_NAME) 2>/dev/null || true; \
		container rmi  $(IMAGE_TAG)      2>/dev/null && echo "Removed $(IMAGE_TAG)" || true; \
	else \
		podman rmi $(IMAGE_TAG) 2>/dev/null && echo "Removed $(IMAGE_TAG)" || true; \
	fi

## test-template  Test template instantiation in an isolated temp directory
test-template:
	@set -e; \
	TMPDIR=$$(mktemp -d); \
	trap "rm -rf $$TMPDIR" EXIT; \
	cp -r . $$TMPDIR/; \
	cd $$TMPDIR; \
	bash scripts/init-from-template.sh test-proj --language python; \
	grep -q "test-proj" Makefile                      && echo "  ✓ Makefile"; \
	grep -q "test-proj" .devcontainer/devcontainer.json && echo "  ✓ devcontainer.json"; \
	grep -q "test-proj" CLAUDE.md                     && echo "  ✓ CLAUDE.md"; \
	grep -q "test-proj" README.md                     && echo "  ✓ README.md (broad sweep)"; \
	test ! -f .claude/commands/init-project.md        && echo "  ✓ init-project removed"; \
	test -f .claude/commands/improve-repo.md          && echo "  ✓ improve-repo preserved"; \
	echo "Template test passed."

## help     Show available targets
help:
	@grep -E '^## ' Makefile | sed 's/^## /  /'
