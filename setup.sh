#!/usr/bin/env bash
# Bootstrap script — detects the host OS and delegates to the appropriate
# platform installer. Run this once before opening the repo in VS Code.
#
# Usage:
#   bash setup.sh
#
# Supported platforms:
#   macOS (Apple Silicon) — installs Podman via Homebrew
#   Windows WSL2          — installs Podman natively inside the Linux distro
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── OS detection ──────────────────────────────────────────────────────────────
# shellcheck source=scripts/detect-os.sh
source "${SCRIPT_DIR}/scripts/detect-os.sh"

echo "Detected OS: ${DETECTED_OS}"
echo ""

# ── Delegate to platform installer ───────────────────────────────────────────
case "${DETECTED_OS}" in
  macos)
    echo "==> macOS: checking Podman..."
    if ! command -v podman &>/dev/null; then
      echo "    Podman not found. Install via: brew install podman"
      echo "    Or install Podman Desktop: https://podman-desktop.io/"
      exit 1
    fi
    echo "    Podman: $(podman --version)"
    echo ""
    echo "Setup complete. Open this folder in VS Code and choose 'Reopen in Container'."
    ;;
  wsl2)
    # shellcheck source=scripts/wsl2/install.sh
    source "${SCRIPT_DIR}/scripts/wsl2/install.sh"
    ;;
esac
