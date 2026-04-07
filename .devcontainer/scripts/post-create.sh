#!/usr/bin/env bash
# Runs once after the devcontainer is created (postCreateCommand).
set -euo pipefail

echo "==> Initialising container environment..."
# Note: credentials are copied by postCreateCommand before this script runs.

# ── Wire workspace .claude/ config into ~/.claude/ ───────────────────────────
# Claude Code reads commands, settings, and memory from ~/.claude/ — not from
# /workspace/.claude/. Symlink each subdirectory so the repo-committed config
# is the live config, and any writes go back into the workspace.

WORKSPACE_CLAUDE="/workspace/.claude"

# commands/ — slash command definitions live in the repo, symlinked into ~/.claude/
if [[ -d "${WORKSPACE_CLAUDE}/commands" ]]; then
  rm -rf "${HOME}/.claude/commands"
  ln -sfn "${WORKSPACE_CLAUDE}/commands" "${HOME}/.claude/commands"
  echo "    Linked ~/.claude/commands → workspace (.claude/commands/)"
fi

# settings.json — repo permissions take precedence over anything copied from host
if [[ -f "${WORKSPACE_CLAUDE}/settings.json" ]]; then
  ln -sfn "${WORKSPACE_CLAUDE}/settings.json" "${HOME}/.claude/settings.json"
  echo "    Linked ~/.claude/settings.json → workspace (.claude/settings.json)"
fi

# memory/ — symlinked via the project directory so Claude Code's runtime writes
# land in the workspace and get committed (portable across machines/rebuilds)
PROJ_DIR="${HOME}/.claude/projects/-workspace"
if [[ -d "${WORKSPACE_CLAUDE}/memory" ]]; then
  mkdir -p "${PROJ_DIR}"
  if [[ -d "${PROJ_DIR}/memory" && ! -L "${PROJ_DIR}/memory" ]]; then
    rm -rf "${PROJ_DIR}/memory"
  fi
  ln -sfn "${WORKSPACE_CLAUDE}/memory" "${PROJ_DIR}/memory"
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
