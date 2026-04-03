#!/usr/bin/env bash
# WSL2 prerequisite installer.
# Installs Podman natively inside WSL2 (no extra VM layer), configures
# subuid/subgid for nested rootless containers, enables the Podman socket,
# and wires VSCode to use it.
set -euo pipefail

# ── Detect distro ─────────────────────────────────────────────────────────────
if [[ ! -f /etc/os-release ]]; then
  echo "error: cannot detect Linux distribution (/etc/os-release missing)." >&2
  exit 1
fi
. /etc/os-release

echo "==> Detected distribution: ${PRETTY_NAME}"

# ── Install Podman + nested container dependencies ────────────────────────────
if ! command -v podman &>/dev/null; then
  echo "==> Installing Podman..."
  case "${ID}" in
    ubuntu|debian)
      sudo apt-get update -qq
      sudo apt-get install -y \
        podman \
        fuse-overlayfs \
        slirp4netns \
        uidmap
      ;;
    fedora)
      sudo dnf install -y podman fuse-overlayfs slirp4netns
      ;;
    rhel|centos|rocky|almalinux)
      sudo dnf install -y podman fuse-overlayfs slirp4netns
      ;;
    *)
      echo "error: unsupported distribution '${ID}'. Install Podman manually then re-run." >&2
      exit 1
      ;;
  esac
else
  echo "==> Podman already installed: $(podman --version)"
fi

# ── subuid / subgid ───────────────────────────────────────────────────────────
# Each entry allocates 65536 subordinate IDs for rootless-in-rootless Podman.
CURRENT_USER="$(whoami)"

if ! grep -q "^${CURRENT_USER}:" /etc/subuid 2>/dev/null; then
  echo "==> Configuring /etc/subuid for ${CURRENT_USER}..."
  echo "${CURRENT_USER}:100000:65536" | sudo tee -a /etc/subuid
fi

if ! grep -q "^${CURRENT_USER}:" /etc/subgid 2>/dev/null; then
  echo "==> Configuring /etc/subgid for ${CURRENT_USER}..."
  echo "${CURRENT_USER}:100000:65536" | sudo tee -a /etc/subgid
fi

# ── Podman socket (Docker-compatible API for VSCode devcontainers) ─────────────
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PODMAN_SOCKET="${RUNTIME_DIR}/podman/podman.sock"

# systemd --user is available in most modern WSL2 distros with systemd enabled.
# If not, fall back to running the socket activation manually.
if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
  echo "==> Podman socket already active."
elif systemctl --user list-unit-files podman.socket &>/dev/null; then
  echo "==> Enabling Podman socket (systemd user)..."
  systemctl --user enable --now podman.socket
else
  echo "==> systemd not available; starting Podman socket via service activation..."
  mkdir -p "$(dirname "${PODMAN_SOCKET}")"
  podman system service --time=0 "unix://${PODMAN_SOCKET}" &
  # Give it a moment to bind
  sleep 1
fi

echo "    Socket: ${PODMAN_SOCKET}"

# ── DOCKER_HOST in shell profile ──────────────────────────────────────────────
for PROFILE in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  if [[ -f "${PROFILE}" ]] && ! grep -q "DOCKER_HOST.*podman" "${PROFILE}" 2>/dev/null; then
    cat >> "${PROFILE}" <<'PROFILE_EOF'

# Podman socket — set by claude-code container setup
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
PROFILE_EOF
    echo "    Added DOCKER_HOST to ${PROFILE}"
  fi
done

export DOCKER_HOST="unix://${PODMAN_SOCKET}"

# ── Wire VSCode (Linux path inside WSL2) ─────────────────────────────────────
_patch_vscode_settings() {
  local settings_file="${1}"
  local socket="${2}"

  mkdir -p "$(dirname "${settings_file}")"
  [[ -f "${settings_file}" ]] || echo '{}' > "${settings_file}"

  python3 - "${settings_file}" "${socket}" <<'PYEOF'
import json, sys
path, socket = sys.argv[1], sys.argv[2]
with open(path) as f:
    s = json.load(f)
s["dev.containers.dockerPath"]       = "podman"
s["dev.containers.dockerSocketPath"] = socket
with open(path, "w") as f:
    json.dump(s, f, indent=2)
print(f"    Updated: {path}")
PYEOF
}

_patch_vscode_settings \
  "${HOME}/.config/Code/User/settings.json" \
  "${PODMAN_SOCKET}"

echo ""
echo "WSL2 setup complete."
echo "  Runtime : $(podman --version)"
echo "  Socket  : ${PODMAN_SOCKET}"
echo ""
echo "Reload your shell:  source ~/.bashrc"
echo "Then open this folder in VS Code → 'Reopen in Container'"
