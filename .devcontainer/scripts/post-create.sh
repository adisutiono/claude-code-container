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
  if [[ -d /run/host-secrets/claude-dir/sessions ]]; then
    sudo cp -r /run/host-secrets/claude-dir/sessions "$HOME/.claude/"
    sudo chown -R "$(id -u):$(id -g)" "$HOME/.claude/sessions"
    echo "    Copied ~/.claude/sessions/"
  fi
fi

if [[ -d /run/host-secrets/gh ]]; then
  sudo cp -r /run/host-secrets/gh/. "$HOME/.config/gh/"
  sudo chown -R "$(id -u):$(id -g)" "$HOME/.config/gh"
  echo "    Copied ~/.config/gh/"
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
  ln -sf ../../scripts/hooks/pre-commit "${WORKSPACE_ROOT}/.git/hooks/pre-commit"
  chmod +x "${WORKSPACE_ROOT}/scripts/hooks/pre-commit"
  echo "    Installed pre-commit hook (secret scanning)"
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
