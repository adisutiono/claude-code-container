#!/usr/bin/env bash
# Watch /run/host-secrets/ for credential changes and auto-copy to ~/.claude/.
# Started as a background process by post-create.sh.
# Uses inotifywait (from inotify-tools) to detect writes on the bind mount.
set -euo pipefail

WATCH_DIR="/run/host-secrets"
LOG_PREFIX="[credential-watcher]"

# Guard: don't run if the watch dir doesn't exist or is empty (no bind mounts)
if [[ ! -d "${WATCH_DIR}" ]]; then
  echo "${LOG_PREFIX} ${WATCH_DIR} not found — exiting."
  exit 0
fi

copy_credentials() {
  # With --userns=keep-id the container user owns mounted files — no sudo needed.
  if [[ -f "${WATCH_DIR}/claude.json" ]]; then
    cp "${WATCH_DIR}/claude.json" "$HOME/.claude.json"
    chmod 600 "$HOME/.claude.json"
    echo "${LOG_PREFIX} Refreshed ~/.claude.json"
  fi

  if [[ -s "${WATCH_DIR}/claude-dir/.credentials.json" ]]; then
    cp "${WATCH_DIR}/claude-dir/.credentials.json" "$HOME/.claude/.credentials.json"
    chmod 600 "$HOME/.claude/.credentials.json"
    echo "${LOG_PREFIX} Refreshed ~/.claude/.credentials.json"
  fi

  # Keychain-exported staging file — written by scripts/macos-refresh-credentials.sh
  # on the host when a token expires. Takes precedence over the filesystem copy
  # because it reflects the latest Keychain state.
  if [[ -s "${WATCH_DIR}/claude-dir/.devcontainer-credentials.json" ]]; then
    cp "${WATCH_DIR}/claude-dir/.devcontainer-credentials.json" "$HOME/.claude/.credentials.json"
    chmod 600 "$HOME/.claude/.credentials.json"
    echo "${LOG_PREFIX} Refreshed ~/.claude/.credentials.json (Keychain export)"
  fi

  if [[ -d "${WATCH_DIR}/claude-dir/sessions" ]]; then
    cp -r "${WATCH_DIR}/claude-dir/sessions" "$HOME/.claude/"
    echo "${LOG_PREFIX} Refreshed ~/.claude/sessions/"
  fi

  if [[ -f "${WATCH_DIR}/gitconfig" ]]; then
    cp "${WATCH_DIR}/gitconfig" "$HOME/.gitconfig"
    chmod 600 "$HOME/.gitconfig"
    echo "${LOG_PREFIX} Refreshed ~/.gitconfig"
  fi
}

echo "${LOG_PREFIX} Watching ${WATCH_DIR} for credential changes..."

# inotifywait monitors for close_write (file written and closed), create,
# and modify events recursively. The --monitor flag keeps it running.
# Debounce: wait 2s after an event before copying, to batch rapid writes.
inotifywait --monitor --recursive \
  --event close_write --event create --event modify \
  --format '%w%f' \
  "${WATCH_DIR}" 2>/dev/null | while read -r changed_file; do
    # Debounce: sleep briefly so rapid successive writes (e.g. editor save)
    # don't trigger multiple copies.
    sleep 2
    # Drain any queued events during the sleep window
    while read -r -t 0.1 _; do :; done
    echo "${LOG_PREFIX} Detected change: ${changed_file}"
    copy_credentials
done
