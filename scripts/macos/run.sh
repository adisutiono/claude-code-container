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
container run \
  --name "${CONTAINER_NAME}" \
  --detach \
  --volume "${WORKSPACE}:/workspace" \
  "${EXTRA_VOLUMES[@]}" \
  "${IMAGE_TAG}" \
  sleep infinity

# postCreateCommand does not run in the macOS attach model.
# Copy credentials from /run/host-secrets into writable home locations.
echo "==> Copying credentials into container..."
# Run as root so we can read host-owned files (e.g. UID 501, mode 600).
# Then chown to claude (UID 1000) so Claude Code can write to them.
container exec "${CONTAINER_NAME}" bash -c '
  if [ -f /run/host-secrets/claude.json ]; then
    sudo cp /run/host-secrets/claude.json /home/claude/.claude.json
    sudo chown claude:claude /home/claude/.claude.json
    sudo chmod 600 /home/claude/.claude.json
    echo "    Copied ~/.claude.json"
  fi
  if [ -d /run/host-secrets/claude-dir ]; then
    for f in settings.json .credentials.json; do
      if [ -f "/run/host-secrets/claude-dir/$f" ]; then
        sudo cp "/run/host-secrets/claude-dir/$f" "/home/claude/.claude/$f"
        sudo chown claude:claude "/home/claude/.claude/$f"
        sudo chmod 600 "/home/claude/.claude/$f"
        echo "    Copied ~/.claude/$f"
      fi
    done
    if [ -d /run/host-secrets/claude-dir/sessions ]; then
      sudo cp -r /run/host-secrets/claude-dir/sessions /home/claude/.claude/
      sudo chown -R claude:claude /home/claude/.claude/sessions
      echo "    Copied ~/.claude/sessions/"
    fi
  fi
  if [ -f /run/host-secrets/gitconfig ]; then
    sudo cp /run/host-secrets/gitconfig /home/claude/.gitconfig
    sudo chown claude:claude /home/claude/.gitconfig
    sudo chmod 644 /home/claude/.gitconfig
    echo "    Copied ~/.gitconfig"
  fi
' 2>&1 || echo "    WARNING: credential copy failed — you may need to run claude login manually"

# Set up memory symlink and pre-commit hook (same as post-create.sh does on WSL2)
container exec "${CONTAINER_NAME}" bash -c '
  WORKSPACE_MEMORY="/workspace/.claude/memory"
  PROJ_DIR="/home/claude/.claude/projects/-workspace"
  if [ -d "${WORKSPACE_MEMORY}" ]; then
    mkdir -p "${PROJ_DIR}"
    if [ -d "${PROJ_DIR}/memory" ] && [ ! -L "${PROJ_DIR}/memory" ]; then
      rm -rf "${PROJ_DIR}/memory"
    fi
    ln -sfn "${WORKSPACE_MEMORY}" "${PROJ_DIR}/memory"
    echo "    Linked Claude Code memory → workspace (.claude/memory/)"
  fi
  if [ -d /workspace/.git ] && [ -f /workspace/scripts/hooks/pre-commit ]; then
    ln -sf ../../scripts/hooks/pre-commit /workspace/.git/hooks/pre-commit
    echo "    Installed pre-commit hook (secret scanning for memory files)"
  fi
' 2>&1 || true

# Run the same environment setup as post-create.sh
container exec "${CONTAINER_NAME}" bash -c '
  sudo mount --make-rshared / 2>/dev/null || true
  sudo chmod 666 /dev/fuse 2>/dev/null || true
  sudo chmod 666 /dev/net/tun 2>/dev/null || true
  podman system migrate 2>/dev/null || true
' 2>&1 || true

echo ""
echo "Container '${CONTAINER_NAME}' is running."
echo "In VS Code: Command Palette → 'Dev Containers: Attach to Running Apple Container...'"
