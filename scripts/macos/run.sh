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
# apple/container does not support --interactive/--tty on detached containers.
# sleep infinity keeps the VM alive so VSCode can attach to it.
container run \
  --name "${CONTAINER_NAME}" \
  --detach \
  --volume "${WORKSPACE}:/workspace" \
  --volume "${HOME}/.claude.json:/home/claude/.claude.json:ro" \
  "${IMAGE_TAG}" \
  sleep infinity

echo ""
echo "Container '${CONTAINER_NAME}' is running."
echo "In VS Code: Command Palette → 'Dev Containers: Attach to Running Apple Container...'"
