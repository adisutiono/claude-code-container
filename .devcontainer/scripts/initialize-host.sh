#!/usr/bin/env bash
# initializeCommand — runs on the HOST before the container is created.
# Ensures placeholder files/directories exist so bind mounts succeed,
# and exports gh auth tokens from the system credential store into a
# container-compatible hosts.yml staging file.
set -euo pipefail

# ── Ensure placeholder files/dirs for bind mounts ───────────────────────────
[ -f "${HOME}/.claude.json" ] || echo "{}" > "${HOME}/.claude.json"
[ -d "${HOME}/.claude" ] || mkdir -p "${HOME}/.claude"
[ -d "${HOME}/.config/gh" ] || mkdir -p "${HOME}/.config/gh"
[ -f "${HOME}/.gitconfig" ] || touch "${HOME}/.gitconfig"

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
    KEYCHAIN_SERVICES=("claude.ai" "api.anthropic.com" "com.anthropic.claude-code" "claude-code")
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
      # Format mirrors Claude Code's .credentials.json structure.
      cat > "${CLAUDE_STAGED}" <<CEOF
{
  "claudeAiOauth": {
    "token": "${CLAUDE_TOKEN}"
  }
}
CEOF
      chmod 600 "${CLAUDE_STAGED}"
      echo "[initializeCommand] Exported Claude token to staging file"
    else
      echo "[initializeCommand] No Claude token found in Keychain — skipping"
    fi
  fi
else
  echo "[initializeCommand] Not macOS — skipping Keychain export"
fi
