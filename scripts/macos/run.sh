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
  EXTRA_VOLUMES+=(--volume "${HOME}/.claude.json:/run/host-secrets/claude.json:ro")
else
  echo "    INFO: ~/.claude.json not found — skipping Claude credential mount"
fi
if [ -d "${HOME}/.claude" ]; then
  EXTRA_VOLUMES+=(--volume "${HOME}/.claude:/run/host-secrets/claude-dir:ro")
else
  echo "    INFO: ~/.claude not found — skipping Claude session mount"
fi
if [ -d "${HOME}/.config/gh" ]; then
  EXTRA_VOLUMES+=(--volume "${HOME}/.config/gh:/home/claude/.config/gh:ro")
else
  echo "    INFO: ~/.config/gh not found — skipping GitHub CLI credential mount"
fi
if [ -f "${HOME}/.gitconfig" ]; then
  EXTRA_VOLUMES+=(--volume "${HOME}/.gitconfig:/run/host-secrets/gitconfig:ro")
else
  echo "    INFO: ~/.gitconfig not found — skipping git config mount"
fi

# apple/container does not support --interactive/--tty on detached containers.
# sleep infinity keeps the VM alive so VSCode can attach to it.
# On macOS, mount the workspace to /workspaces/<basename> to match the WSL2
# Dev Containers default and keep paths consistent across platforms.
WORKSPACE_NAME="$(basename "${WORKSPACE}")"
CONTAINER_WORKSPACE="/workspaces/${WORKSPACE_NAME}"

container run \
  --name "${CONTAINER_NAME}" \
  --detach \
  --volume "${WORKSPACE}:${CONTAINER_WORKSPACE}" \
  "${EXTRA_VOLUMES[@]}" \
  "${IMAGE_TAG}" \
  sleep infinity

# postCreateCommand does not run in the macOS attach model.
# Run post-create.sh from the workspace with CWD set to the workspace folder,
# mirroring how devcontainer.json invokes it on WSL2.
echo "==> Running post-create setup..."
container exec --workdir "${CONTAINER_WORKSPACE}" "${CONTAINER_NAME}" \
  bash .devcontainer/scripts/post-create.sh \
  2>&1 || echo "    WARNING: post-create.sh failed — check container logs"

echo ""
echo "Container '${CONTAINER_NAME}' is running."
echo "In VS Code: Command Palette → 'Dev Containers: Attach to Running Apple Container...'"
