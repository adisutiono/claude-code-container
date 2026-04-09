#!/usr/bin/env bash
# Update .knowledge/audit-log.md when a PR branch is merged or declined.
# Finds the entry with **Branch:** <branch> and flips its **Status:** proposed
# to the requested status. Exits 0 if an entry was updated, 1 if not found.
#
# Usage: sync-knowledge.sh <branch-name> [merged|declined]
# Called by: .github/workflows/sync-knowledge.yml on PR close
set -euo pipefail

BRANCH="${1:?Usage: sync-knowledge.sh <branch-name> [merged|declined]}"
NEW_STATUS="${2:-merged}"
AUDIT_LOG=".knowledge/audit-log.md"

if [[ ! -f "${AUDIT_LOG}" ]]; then
  echo "==> ${AUDIT_LOG} not found — nothing to update"
  exit 1
fi

# awk pass: find the line that exactly matches "**Branch:** <branch>" and
# update the next "**Status:** proposed" line within that entry.
# Exact matching avoids partial hits (e.g. "fix/foo" matching "fix/foobar").
# Only 'proposed' entries are updated — already-merged/declined entries are left alone.
UPDATED=$(awk \
  -v branch="${BRANCH}" \
  -v newstatus="${NEW_STATUS}" \
  -v changed=0 '
    $0 == ("**Branch:** " branch)  { found=1 }
    found && $0 == "**Status:** proposed" {
      $0 = "**Status:** " newstatus
      found=0
      changed++
    }
    { print }
    END { exit (changed > 0) ? 0 : 1 }
  ' "${AUDIT_LOG}") || {
  echo "==> No 'proposed' entry found for branch '${BRANCH}' — audit-log unchanged"
  exit 1
}

printf '%s\n' "${UPDATED}" > "${AUDIT_LOG}"
echo "==> Marked branch '${BRANCH}' as '${NEW_STATUS}' in ${AUDIT_LOG}"
