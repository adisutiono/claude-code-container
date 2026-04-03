#!/usr/bin/env bash
# Bootstrap script — detects the host OS and delegates to the appropriate
# platform installer. Run this once before opening the repo in VS Code.
#
# Usage:
#   bash setup.sh
#
# Supported platforms:
#   macOS 15+ (Sequoia)  — installs Podman via Homebrew, Apple VZ backend
#   Windows WSL2         — installs Podman natively inside the Linux distro
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
    # shellcheck source=scripts/macos/install.sh
    source "${SCRIPT_DIR}/scripts/macos/install.sh"
    ;;
  wsl2)
    # shellcheck source=scripts/wsl2/install.sh
    source "${SCRIPT_DIR}/scripts/wsl2/install.sh"
    ;;
esac
