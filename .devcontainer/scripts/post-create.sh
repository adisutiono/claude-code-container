#!/usr/bin/env bash
# Runs once after the devcontainer is created (postCreateCommand).
set -euo pipefail

echo "==> Initialising container environment..."
# Note: credentials are copied by postCreateCommand before this script runs.

# ── Portable memory: symlink Claude Code's runtime memory to the workspace ───
# Claude Code writes project memory to ~/.claude/projects/<path-hash>/memory/.
# By symlinking that path to /workspace/.claude/memory/, memory files land in
# the git workspace and travel with the repo — portable across machines.
# Claude Code stores project memory at ~/.claude/projects/<path-with-dashes>/memory/.
# The workspace is /workspace, so the project dir is "-workspace".
# Symlink that memory dir into the git workspace so memory files are committed
# and travel with the repo — portable across machines and container rebuilds.
WORKSPACE_MEMORY="/workspace/.claude/memory"
PROJ_DIR="${HOME}/.claude/projects/-workspace"
if [[ -d "${WORKSPACE_MEMORY}" ]]; then
  mkdir -p "${PROJ_DIR}"
  # Replace existing memory dir (not a symlink) with the symlink
  if [[ -d "${PROJ_DIR}/memory" && ! -L "${PROJ_DIR}/memory" ]]; then
    rm -rf "${PROJ_DIR}/memory"
  fi
  ln -sfn "${WORKSPACE_MEMORY}" "${PROJ_DIR}/memory"
  echo "    Linked Claude Code memory → workspace (.claude/memory/)"
fi

# Install pre-commit hook for secret scanning
if [[ -d /workspace/.git && -f /workspace/scripts/hooks/pre-commit ]]; then
  ln -sf ../../scripts/hooks/pre-commit /workspace/.git/hooks/pre-commit
  echo "    Installed pre-commit hook (secret scanning for memory files)"
fi

# Make the root mount rshared so rootless Podman can propagate bind mounts into
# inner containers. Without this, Podman warns "/" is not a shared mount and
# volume mounts inside nested containers silently fail or are missing.
sudo mount --make-rshared / 2>/dev/null || true

# /dev/fuse is created by the kernel as root-only; open it up for rootless Podman.
sudo chmod 666 /dev/fuse     2>/dev/null || true
sudo chmod 666 /dev/net/tun 2>/dev/null || true

# Migrate Podman storage schema if needed (safe no-op on first run)
podman system migrate 2>/dev/null || true

# Smoke-test: verify rootless Podman can pull and run a minimal image.
# This confirms nested container support is functional before Claude Code starts.
echo "==> Verifying nested container support..."
if podman run --rm docker.io/library/hello-world:latest &>/dev/null; then
  echo "    OK — nested containers operational"
else
  echo "    WARNING: nested container test failed. Check runArgs in devcontainer.json."
fi

echo ""
echo "Environment ready."
echo "  Claude Code : $(claude --version 2>/dev/null || echo '(run: claude --version)')"
echo "  Podman      : $(podman --version)"
