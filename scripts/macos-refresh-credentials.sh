#!/usr/bin/env bash
# Refresh Claude Code and GitHub credentials from the macOS Keychain without
# rebuilding the container.
#
# Run this script ON THE HOST (not inside the container) after re-authenticating
# Claude Code (e.g. after a token expiry). It re-extracts credentials from the
# Keychain and writes them to the staging files that are bind-mounted into the
# container. The container-side credential-watcher picks up the change
# automatically via inotifywait — no rebuild required.
#
# Usage:
#   bash scripts/macos-refresh-credentials.sh   # from the repo root on the host
#   make refresh-credentials                     # equivalent shorthand
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[refresh-credentials] This script is for macOS only." >&2
  echo "                      On WSL2/Linux, credentials live on the filesystem" >&2
  echo "                      and the container-side watcher handles them directly." >&2
  exit 1
fi

echo "[refresh-credentials] Re-extracting credentials from macOS Keychain..."

# ── Claude Code credentials ───────────────────────────────────────────────────
CLAUDE_STAGED="${HOME}/.claude/.devcontainer-credentials.json"
CLAUDE_CREDS="${HOME}/.claude/.credentials.json"
CLAUDE_TOKEN=""

KEYCHAIN_SERVICES=("Claude Code-credentials" "claude.ai" "api.anthropic.com" "com.anthropic.claude-code" "claude-code")
if [[ -n "${CLAUDE_KEYCHAIN_SERVICE:-}" ]]; then
  KEYCHAIN_SERVICES=("${CLAUDE_KEYCHAIN_SERVICE}" "${KEYCHAIN_SERVICES[@]}")
fi

for SERVICE in "${KEYCHAIN_SERVICES[@]}"; do
  CLAUDE_TOKEN="$(security find-generic-password -s "${SERVICE}" -w 2>/dev/null || true)"
  if [[ -n "${CLAUDE_TOKEN}" ]]; then
    echo "[refresh-credentials] Found Claude token in Keychain (service: ${SERVICE})"
    break
  fi
  CLAUDE_TOKEN="$(security find-internet-password -s "${SERVICE}" -w 2>/dev/null || true)"
  if [[ -n "${CLAUDE_TOKEN}" ]]; then
    echo "[refresh-credentials] Found Claude token in Keychain (internet-password: ${SERVICE})"
    break
  fi
done

if [[ -n "${CLAUDE_TOKEN}" ]]; then
  # Write to staging file — the bind mount at /run/host-secrets/claude-dir/
  # makes this immediately visible inside the container.
  echo "${CLAUDE_TOKEN}" > "${CLAUDE_STAGED}"
  chmod 600 "${CLAUDE_STAGED}"
  echo "[refresh-credentials] Updated ${CLAUDE_STAGED}"

  # Also update the filesystem credentials file so future container restarts
  # pick up the latest token even if Keychain extraction is skipped.
  echo "${CLAUDE_TOKEN}" > "${CLAUDE_CREDS}"
  chmod 600 "${CLAUDE_CREDS}"
  echo "[refresh-credentials] Updated ${CLAUDE_CREDS}"
else
  # No Keychain token found — check if filesystem credentials exist instead.
  if [[ -s "${CLAUDE_CREDS}" ]] && grep -q '"token"' "${CLAUDE_CREDS}" 2>/dev/null; then
    echo "[refresh-credentials] No Keychain token found; filesystem credentials exist and will be used."
  else
    echo "[refresh-credentials] WARNING: No Claude token found in Keychain or on filesystem." >&2
    echo "                      Run 'claude auth login' on the host to authenticate." >&2
  fi
fi

# ── GitHub CLI credentials ────────────────────────────────────────────────────
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
    echo "[refresh-credentials] Updated ${GH_STAGED}"
  else
    echo "[refresh-credentials] gh authenticated but token extraction failed — skipping"
  fi
else
  echo "[refresh-credentials] gh not installed or not authenticated — skipping"
fi

echo ""
echo "[refresh-credentials] Done. The container-side credential-watcher will apply"
echo "                      the updated credentials automatically within a few seconds."
echo "                      Check: cat /tmp/credential-watcher.log  (inside the container)"
