#!/usr/bin/env bash
# Start the Claude Code container using apple/container.
# Each container is a dedicated Linux VM (Virtualization.framework),
# so nested Podman runs inside with full Linux capabilities — no extra flags needed.
set -euo pipefail

CONTAINER_NAME="${CLAUDE_CONTAINER_NAME:-claude-code-env}"
IMAGE_TAG="${CLAUDE_IMAGE_TAG:-claude-code-devcontainer:latest}"
WORKSPACE="${CLAUDE_WORKSPACE:-$(pwd)}"

# Stop and remove any previous instance of the same name
if container inspect "${CONTAINER_NAME}" &>/dev/null; then
  echo "==> Removing existing container '${CONTAINER_NAME}'..."
  container stop "${CONTAINER_NAME}" 2>/dev/null || true
  container rm   "${CONTAINER_NAME}" 2>/dev/null || true
fi

echo "==> Starting container '${CONTAINER_NAME}'..."

# Build optional credential mounts only if the files/dirs exist on the host.
EXTRA_VOLUMES=()
if [ -f "${HOME}/.claude.json" ]; then
  EXTRA_VOLUMES+=(--volume "${HOME}/.claude.json:/home/claude/.claude.json:ro")
else
  echo "    INFO: ~/.claude.json not found — skipping Claude credential mount"
fi
if [ -d "${HOME}/.config/gh" ]; then
  EXTRA_VOLUMES+=(--volume "${HOME}/.config/gh:/home/claude/.config/gh:ro")
else
  echo "    INFO: ~/.config/gh not found — skipping GitHub CLI credential mount"
fi
if [ -f "${HOME}/.gitconfig" ]; then
  EXTRA_VOLUMES+=(--volume "${HOME}/.gitconfig:/home/claude/.gitconfig:ro")
else
  echo "    INFO: ~/.gitconfig not found — skipping git config mount"
fi

# apple/container does not support --interactive/--tty on detached containers.
# sleep infinity keeps the VM alive so VSCode can attach to it.
container run \
  --name "${CONTAINER_NAME}" \
  --detach \
  --volume "${WORKSPACE}:/workspace" \
  "${EXTRA_VOLUMES[@]}" \
  "${IMAGE_TAG}" \
  sleep infinity

echo ""
echo "Container '${CONTAINER_NAME}' is running."
echo "In VS Code: Command Palette → 'Dev Containers: Attach to Running Apple Container...'"
