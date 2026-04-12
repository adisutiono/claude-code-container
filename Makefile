.PHONY: setup build status clean test-template refresh-credentials help

IMAGE_TAG        ?= claude-code-devcontainer:latest

# Detect OS once; used by targets that need platform-specific behaviour
# $(shell ...) is used instead of != for compatibility with GNU Make 3.81 (ships with macOS)
_OS := $(shell bash -c 'source scripts/detect-os.sh && echo $$DETECTED_OS')

# macOS is always Apple Silicon (arm64); WSL2 / Linux runs on x86_64.
PLATFORM_macos   := linux/arm64
PLATFORM_wsl2    := linux/amd64
PLATFORM_linux   := linux/amd64
_PLATFORM        := $(PLATFORM_$(_OS))

## setup    Detect OS and install prerequisites
setup:
	@bash setup.sh

## build    Build the container image with podman
build:
	@echo "Building on: $(_OS) (platform: $(_PLATFORM))"
	@podman build \
		--platform $(_PLATFORM) \
		--file .devcontainer/Containerfile \
		--tag $(IMAGE_TAG) \
		--build-arg USERNAME=claude \
		--build-arg USER_UID=1000 \
		--build-arg USER_GID=1000 \
		--build-arg TARGETPLATFORM=$(_PLATFORM) \
		.

## status   Show runtime and container state
status:
	@echo "OS: $(_OS)"
	@podman --version 2>/dev/null || echo "podman: not found"

## clean    Remove the container image
clean:
	@podman rmi $(IMAGE_TAG) 2>/dev/null && echo "Removed $(IMAGE_TAG)" || true

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

## refresh-credentials   Re-extract macOS Keychain credentials into the running container (no rebuild needed)
refresh-credentials:
	@bash scripts/macos-refresh-credentials.sh

## help     Show available targets
help:
	@grep -E '^## ' Makefile | sed 's/^## /  /'
