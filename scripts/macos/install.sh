#!/usr/bin/env bash
# macOS prerequisite installer.
# Installs apple/container (native Virtualization.framework runtime) and
# enables the experimental VSCode Dev Containers support for it.
set -euo pipefail

# ── Homebrew ──────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi

# ── apple/container ────────────────────────────────────────────────────────────
# Distributed via the apple/apple Homebrew tap.
if ! command -v container &>/dev/null; then
  echo "==> Installing apple/container..."
  brew install apple/apple/container
else
  echo "==> apple/container already installed: $(container --version 2>/dev/null || true)"
fi

# ── VSCode experimental Apple Container support ───────────────────────────────
# Enables "Dev Containers: Attach to Running Apple Container..." command.
# https://github.com/microsoft/vscode-remote-release/issues/11012
_patch_vscode_settings() {
  local settings_file="${1}"

  mkdir -p "$(dirname "${settings_file}")"
  [[ -f "${settings_file}" ]] || echo '{}' > "${settings_file}"

  python3 - "${settings_file}" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
s["dev.containers.experimentalAppleContainerSupport"] = True
with open(path, "w") as f:
    json.dump(s, f, indent=2)
print(f"    Updated: {path}")
PYEOF
}

_patch_vscode_settings "${HOME}/Library/Application Support/Code/User/settings.json"

# Insiders build — only patch if it exists
INSIDERS="${HOME}/Library/Application Support/Code - Insiders/User/settings.json"
[[ -d "$(dirname "${INSIDERS}")" ]] && _patch_vscode_settings "${INSIDERS}"

echo ""
echo "macOS setup complete."
echo "  Runtime : apple/container (Apple Virtualization.framework)"
echo ""
echo "Next steps:"
echo "  1. make build          — build the container image"
echo "  2. make run            — start the container"
echo "  3. VS Code → Command Palette → 'Dev Containers: Attach to Running Apple Container...'"
