#!/usr/bin/env bash
# Runs once after the devcontainer is created (postCreateCommand).
# Handles credential copying, .claude/ config wiring, and Podman setup.
set -euo pipefail

echo "==> Initialising container environment..."

# ── Copy credentials from read-only host mounts ─────────────────────────────
if [[ -f /run/host-secrets/claude.json ]]; then
  cp /run/host-secrets/claude.json "$HOME/.claude.json"
  chmod 600 "$HOME/.claude.json"
  echo "    Copied ~/.claude.json"
fi

if [[ -d /run/host-secrets/claude-dir ]]; then
  for f in .credentials.json; do
    if [[ -f "/run/host-secrets/claude-dir/$f" ]]; then
      cp "/run/host-secrets/claude-dir/$f" "$HOME/.claude/$f"
      chmod 600 "$HOME/.claude/$f"
      echo "    Copied ~/.claude/$f"
    fi
  done
  if [[ -d /run/host-secrets/claude-dir/sessions ]]; then
    cp -r /run/host-secrets/claude-dir/sessions "$HOME/.claude/"
    echo "    Copied ~/.claude/sessions/"
  fi
fi

if [[ -f /run/host-secrets/gitconfig ]]; then
  cp /run/host-secrets/gitconfig "$HOME/.gitconfig"
  chmod 600 "$HOME/.gitconfig"
  echo "    Copied ~/.gitconfig"
fi

# ── Shadow /run/host-secrets/ after copy ─────────────────────────────────────
# Credentials have been copied to writable locations. The read-only mount is no
# longer needed — shadow it with an empty tmpfs so the originals can't be read
# by a compromised subprocess for the remainder of the container's lifetime.
sudo mount -t tmpfs -o size=4k,noexec,nosuid,nodev tmpfs /run/host-secrets 2>/dev/null \
  && echo "    Shadowed /run/host-secrets/ (credentials already copied)" \
  || echo "    Note: could not shadow /run/host-secrets/ (non-critical)"

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
PROJ_NAME=$(echo "${WORKSPACE_ROOT}" | sed 's|/|-|g')
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
sudo chmod 666 /dev/net/tun 2>/dev/null || true
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
