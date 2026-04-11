#!/usr/bin/env bash
# initializeCommand — runs on the HOST before the container is created.
# Ensures placeholder files/directories exist so bind mounts succeed,
# exports gh auth tokens from the system credential store into a
# container-compatible hosts.yml staging file, and persists HOST_UID/HOST_GID
# for cross-platform UID mapping.
set -euo pipefail

# ── Ensure placeholder files/dirs for bind mounts ───────────────────────────
[ -f "${HOME}/.claude.json" ] || echo "{}" > "${HOME}/.claude.json"
[ -d "${HOME}/.claude" ] || mkdir -p "${HOME}/.claude"
[ -d "${HOME}/.config/gh" ] || mkdir -p "${HOME}/.config/gh"
[ -f "${HOME}/.gitconfig" ] || touch "${HOME}/.gitconfig"

# ── Persist HOST_UID / HOST_GID for devcontainer.json ────────────────────────
# devcontainer.json references ${localEnv:HOST_UID:1000} in build args and
# runArgs. VS Code reads these from its process environment, which inherits
# from the user's shell profile. We write a small env file and add a source
# line to the profile so the vars are available on every subsequent launch.
#
# On WSL2 (UID 1000) the default of 1000 already matches, so this is mainly
# needed for macOS where the default UID is 501.
HOST_ENV_FILE="${HOME}/.devcontainer-host-env"
cat > "${HOST_ENV_FILE}" <<HEOF
export HOST_UID=$(id -u)
export HOST_GID=$(id -g)
HEOF

# Source it now (for any child processes in this script).
# shellcheck disable=SC1090
source "${HOST_ENV_FILE}"

# Add persistent source line to the user's login profile (zsh on macOS,
# bash on WSL2). Use .zprofile / .bash_profile so GUI-launched VS Code
# (which sources login profiles) picks up the vars.
if [[ "$(uname -s)" == "Darwin" ]]; then
  PROFILE="${HOME}/.zprofile"
else
  PROFILE="${HOME}/.bash_profile"
fi
MARKER="# devcontainer-host-env"
if ! grep -qF "${MARKER}" "${PROFILE}" 2>/dev/null; then
  printf '\n%s\n[ -f "%s" ] && source "%s"\n' \
    "${MARKER}" "${HOST_ENV_FILE}" "${HOST_ENV_FILE}" >> "${PROFILE}"
  echo "[initializeCommand] Added HOST_UID/HOST_GID to ${PROFILE}"
  echo "[initializeCommand] NOTE: If this is the first run, restart VS Code so it"
  echo "                    picks up HOST_UID=${HOST_UID} HOST_GID=${HOST_GID},"
  echo "                    then Rebuild Container."
else
  echo "[initializeCommand] HOST_UID=${HOST_UID} HOST_GID=${HOST_GID}"
fi

# ── Export gh OAuth token for container use ──────────────────────────────────
# On macOS, gh stores tokens in the system Keychain — not in hosts.yml.
# The container can't access the Keychain, so we extract the token here
# (on the host) and write a container-compatible hosts.yml staging file.
# post-create.sh will use this as the container's hosts.yml.
GH_STAGED="${HOME}/.config/gh/.devcontainer-hosts.yml"

if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  GH_TOKEN="$(gh auth token 2>/dev/null || true)"
  if [[ -n "${GH_TOKEN}" ]]; then
    GH_USER="$(gh api user --jq .login 2>/dev/null || echo "")"
    GH_PROTO="$(gh config get git_protocol 2>/dev/null || echo "https")"
    cat > "${GH_STAGED}" <<YEOF
github.com:
    oauth_token: ${GH_TOKEN}
    git_protocol: ${GH_PROTO}
    user: ${GH_USER}
YEOF
    chmod 600 "${GH_STAGED}"
    echo "[initializeCommand] Exported gh token to staging file"
  else
    echo "[initializeCommand] gh authenticated but token extraction failed — skipping"
    rm -f "${GH_STAGED}"
  fi
else
  echo "[initializeCommand] gh not installed or not authenticated — skipping token export"
  rm -f "${GH_STAGED}"
fi

# ── Export Claude Code credentials for container use ───────────────────────
# On macOS, Claude Code may store OAuth tokens in the system Keychain rather
# than in ~/.claude/.credentials.json. The container can't access the Keychain,
# so we extract the token here (on the host) and write a staging file.
# post-create.sh will use this as the container's .credentials.json.
CLAUDE_STAGED="${HOME}/.claude/.devcontainer-credentials.json"
rm -f "${CLAUDE_STAGED}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  CLAUDE_CREDS="${HOME}/.claude/.credentials.json"

  # Skip if filesystem credentials already contain a token
  if [[ -s "${CLAUDE_CREDS}" ]] && grep -q '"token"' "${CLAUDE_CREDS}" 2>/dev/null; then
    echo "[initializeCommand] Claude credentials already on filesystem — skipping Keychain export"
  else
    # Try known Keychain service names used by Claude Code.
    # Allow override via env var for non-standard installations.
    CLAUDE_TOKEN=""
    KEYCHAIN_SERVICES=("Claude Code-credentials" "claude.ai" "api.anthropic.com" "com.anthropic.claude-code" "claude-code")
    if [[ -n "${CLAUDE_KEYCHAIN_SERVICE:-}" ]]; then
      KEYCHAIN_SERVICES=("${CLAUDE_KEYCHAIN_SERVICE}" "${KEYCHAIN_SERVICES[@]}")
    fi

    for SERVICE in "${KEYCHAIN_SERVICES[@]}"; do
      CLAUDE_TOKEN="$(security find-generic-password -s "${SERVICE}" -w 2>/dev/null || true)"
      if [[ -n "${CLAUDE_TOKEN}" ]]; then
        echo "[initializeCommand] Found Claude token in Keychain (service: ${SERVICE})"
        break
      fi
      # Also try internet password entries (URL-based)
      CLAUDE_TOKEN="$(security find-internet-password -s "${SERVICE}" -w 2>/dev/null || true)"
      if [[ -n "${CLAUDE_TOKEN}" ]]; then
        echo "[initializeCommand] Found Claude token in Keychain (internet-password: ${SERVICE})"
        break
      fi
    done

    if [[ -n "${CLAUDE_TOKEN}" ]]; then
      # Write staging file. post-create.sh will move this into place.
      # The keychain value is the complete credentials JSON — write it directly.
      echo "${CLAUDE_TOKEN}" > "${CLAUDE_STAGED}"
      chmod 600 "${CLAUDE_STAGED}"
      echo "[initializeCommand] Exported Claude token to staging file"
    else
      echo "[initializeCommand] No Claude token found in Keychain — skipping"
    fi
  fi
else
  echo "[initializeCommand] Not macOS — skipping Keychain export"
fi
