#!/usr/bin/env bash
# Runs once after the devcontainer is created (postCreateCommand).
set -euo pipefail

echo "==> Initialising container environment..."

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
