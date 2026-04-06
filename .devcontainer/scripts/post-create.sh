#!/usr/bin/env bash
# Runs once after the devcontainer is created (postCreateCommand).
set -euo pipefail

echo "==> Initialising container environment..."

# Copy host credentials into writable container-local locations.
# Mounted read-only at /run/host-secrets/ so the host files are never modified.
# Claude Code needs to write back to ~/.claude.json (e.g. security guide acceptance).
# Host files are mounted read-only at /run/host-secrets/ but may be owned by
# the host UID (e.g. 501 on macOS), which the container user cannot read.
# Use sudo to copy them into writable, claude-owned locations.
if [ -f /run/host-secrets/claude.json ]; then
  cp /run/host-secrets/claude.json "${HOME}/.claude.json"
  chmod 600 "${HOME}/.claude.json"
  echo "    Copied Claude credentials to ~/.claude.json"
else
  echo "    INFO: /run/host-secrets/claude.json not found — skipping"
fi
if [ -f /run/host-secrets/gitconfig ]; then
  cp /run/host-secrets/gitconfig "${HOME}/.gitconfig"
  chmod 644 "${HOME}/.gitconfig"
  echo "    Copied git config to ~/.gitconfig"
else
  echo "    INFO: /run/host-secrets/gitconfig not found — skipping"
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
