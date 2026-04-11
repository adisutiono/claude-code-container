#!/usr/bin/env bash
# Runs once after the devcontainer is created (postCreateCommand).
# Handles credential copying, .claude/ config wiring, and Podman setup.
set -euo pipefail

echo "==> Initialising container environment..."

# ── Copy credentials from read-only host mounts ─────────────────────────────
# Host-mounted files retain their host UID (e.g. 501 on macOS, 1000 on WSL2)
# and may be mode 600. Use sudo to read them, then chown to the container user.
if [[ -f /run/host-secrets/claude.json ]]; then
  sudo cp /run/host-secrets/claude.json "$HOME/.claude.json"
  sudo chown "$(id -u):$(id -g)" "$HOME/.claude.json"
  chmod 600 "$HOME/.claude.json"
  echo "    Copied ~/.claude.json"
fi

if [[ -d /run/host-secrets/claude-dir ]]; then
  if [[ -f "/run/host-secrets/claude-dir/.credentials.json" ]]; then
    sudo cp "/run/host-secrets/claude-dir/.credentials.json" "$HOME/.claude/.credentials.json"
    sudo chown "$(id -u):$(id -g)" "$HOME/.claude/.credentials.json"
    chmod 600 "$HOME/.claude/.credentials.json"
    echo "    Copied ~/.claude/.credentials.json"
  fi
  # If the host exported Keychain credentials, use them (overrides empty file copy).
  # This handles macOS where Claude Code stores tokens in the Keychain, not on disk.
  if [[ -f "$HOME/.claude/.devcontainer-credentials.json" ]]; then
    mv "$HOME/.claude/.devcontainer-credentials.json" "$HOME/.claude/.credentials.json"
    chmod 600 "$HOME/.claude/.credentials.json"
    echo "    Applied Keychain-exported Claude credentials"
  fi
  if [[ -d /run/host-secrets/claude-dir/sessions ]]; then
    sudo cp -r /run/host-secrets/claude-dir/sessions "$HOME/.claude/"
    sudo chown -R "$(id -u):$(id -g)" "$HOME/.claude/sessions"
    echo "    Copied ~/.claude/sessions/"
  fi
fi

if [[ -d /run/host-secrets/gh ]]; then
  sudo cp -r /run/host-secrets/gh/. "$HOME/.config/gh/"
  sudo chown -R "$(id -u):$(id -g)" "$HOME/.config/gh"

  # If the host exported a token-bearing staging file, use it as hosts.yml.
  # This handles macOS where gh stores tokens in the Keychain (not in hosts.yml).
  if [[ -f "$HOME/.config/gh/.devcontainer-hosts.yml" ]]; then
    mv "$HOME/.config/gh/.devcontainer-hosts.yml" "$HOME/.config/gh/hosts.yml"
    chmod 600 "$HOME/.config/gh/hosts.yml"
    echo "    Copied ~/.config/gh/ (with exported token)"
  else
    echo "    Copied ~/.config/gh/"
  fi
fi

if [[ -f /run/host-secrets/gitconfig ]]; then
  sudo cp /run/host-secrets/gitconfig "$HOME/.gitconfig"
  sudo chown "$(id -u):$(id -g)" "$HOME/.gitconfig"
  chmod 600 "$HOME/.gitconfig"
  echo "    Copied ~/.gitconfig"
fi

# ── Start credential watcher ─────────────────────────────────────────────────
# Watch /run/host-secrets/ for changes and auto-copy updated credentials.
# This replaces the old tmpfs-shadow approach so credentials stay fresh when
# the host refreshes tokens (e.g. Claude auth rotation).
# Try workspace copy first (latest), fall back to image-bundled copy.
WATCHER_SCRIPT="${WORKSPACE_ROOT:-.}/.devcontainer/scripts/credential-watcher.sh"
[[ -x "${WATCHER_SCRIPT}" ]] || WATCHER_SCRIPT="${HOME}/.devcontainer/credential-watcher.sh"
if [[ -x "${WATCHER_SCRIPT}" ]] && command -v inotifywait &>/dev/null; then
  nohup bash "${WATCHER_SCRIPT}" >> /tmp/credential-watcher.log 2>&1 &
  echo "    Started credential watcher (PID $!, log: /tmp/credential-watcher.log)"
else
  echo "    Note: credential watcher not started (inotifywait or script not found)"
fi

# ── Wire workspace .claude/ config into ~/.claude/ ───────────────────────────
# Claude Code reads commands, settings, and memory from ~/.claude/ — not from
# the workspace .claude/. Symlink so the repo-committed config is the live config.
# $PWD is the workspaceFolder set by devcontainer.json (e.g. /workspaces/my-project).
WORKSPACE_ROOT="${PWD}"
WORKSPACE_CLAUDE="${WORKSPACE_ROOT}/.claude"

if [[ -d "${WORKSPACE_CLAUDE}/commands" ]]; then
  rm -rf "${HOME}/.claude/commands"
  ln -sfn "${WORKSPACE_CLAUDE}/commands" "${HOME}/.claude/commands"
  echo "    Linked ~/.claude/commands → workspace"
fi

if [[ -f "${WORKSPACE_CLAUDE}/settings.json" ]]; then
  rm -f "${HOME}/.claude/settings.json"
  ln -sfn "${WORKSPACE_CLAUDE}/settings.json" "${HOME}/.claude/settings.json"
  echo "    Linked ~/.claude/settings.json → workspace"
fi

# Claude Code derives its project dir from the workspace path:
# /workspaces/my-project → ~/.claude/projects/-workspaces-my-project/
PROJ_NAME="${WORKSPACE_ROOT//\//-}"
PROJ_DIR="${HOME}/.claude/projects/${PROJ_NAME}"
if [[ -d "${WORKSPACE_CLAUDE}/memory" ]]; then
  mkdir -p "${PROJ_DIR}"
  if [[ -d "${PROJ_DIR}/memory" && ! -L "${PROJ_DIR}/memory" ]]; then
    rm -rf "${PROJ_DIR}/memory"
  fi
  ln -sfn "${WORKSPACE_CLAUDE}/memory" "${PROJ_DIR}/memory"
  echo "    Linked ~/.claude/projects/${PROJ_NAME}/memory → workspace"
fi

# ── Install pre-commit hook for secret scanning ─────────────────────────────
if [[ -d "${WORKSPACE_ROOT}/.git" && -f "${WORKSPACE_ROOT}/scripts/hooks/pre-commit" ]]; then
  mkdir -p "${WORKSPACE_ROOT}/.git/hooks"
  rm -f "${WORKSPACE_ROOT}/.git/hooks/pre-commit"
  ln -s ../../scripts/hooks/pre-commit "${WORKSPACE_ROOT}/.git/hooks/pre-commit"
  chmod +x "${WORKSPACE_ROOT}/scripts/hooks/pre-commit"
  echo "    Installed pre-commit hook (secret scanning)"
fi

# ── Verify workspace file ownership ──────────────────────────────────────────
# With --userns=keep-id, the host user's UID is mapped to the container user's
# UID. If HOST_UID was set correctly in the user's environment (see
# initializeCommand), the container user UID matches the host UID, and virtiofs
# files appear owned by the container user on both WSL2 and macOS.
if [[ -d "${WORKSPACE_ROOT}" ]]; then
  WORKSPACE_UID="$(stat -c %u "${WORKSPACE_ROOT}")"
  CONTAINER_UID="$(id -u)"
  if [[ "${WORKSPACE_UID}" == "${CONTAINER_UID}" ]]; then
    echo "    Workspace ownership OK (UID ${CONTAINER_UID})"
  elif [[ "${WORKSPACE_UID}" == "65534" ]]; then
    echo "    WARNING: Workspace files owned by nobody (UID 65534)."
    echo "    The host UID is not mapped in the container's user namespace."
    echo "    Set HOST_UID/HOST_GID in your shell profile and rebuild:"
    echo "      echo 'export HOST_UID=\$(id -u) HOST_GID=\$(id -g)' >> ~/.zprofile"
    echo "    Then: Cmd+Shift+P → Dev Containers: Rebuild Container"
  else
    echo "    WARNING: Workspace owned by UID ${WORKSPACE_UID}, container user is ${CONTAINER_UID}."
    echo "    Set HOST_UID=${WORKSPACE_UID} HOST_GID=$(stat -c %g "${WORKSPACE_ROOT}") in your shell profile and rebuild."
  fi
fi

# ── Podman / nested container setup ──────────────────────────────────────────
sudo mount --make-rshared / 2>/dev/null || true
sudo chmod 666 /dev/fuse     2>/dev/null || true
podman system migrate 2>/dev/null || true

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
