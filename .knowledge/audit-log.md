---
type: knowledge
category: audit-log
last_updated: 2026-04-09
schema_version: 1
---

# Audit Log

Append-only log of findings from `/improve-repo` and `/audit-security` runs.
Entries are prepended (newest first).

## 2026-04-09 — /improve-repo

**Findings:** 4 (0 critical, 2 recommended, 2 nice-to-have)
**Branch:** improve/2026-04-09
**Status:** proposed

### Finding: CI template test missing .knowledge/ assertions
- **Severity:** recommended
- **Category:** ci
- **Description:** `test-template` job verifies Makefile/CLAUDE.md substitution and command removal, but never asserts `.knowledge/` files exist after instantiation. A broken `post-init.sh` knowledge reset would silently pass CI.
- **Resolution:** Added four `[[ -f .knowledge/*.md ]]` assertions to `build.yml`.

### Finding: README project structure tree stale
- **Severity:** recommended
- **Category:** docs
- **Description:** Tree missing `.knowledge/` directory and `credential-watcher.sh`. `post-create.sh` description said "Smoke-tests nested container support on first open" — now it does credential copy, watcher start, symlinks, and Podman setup.
- **Resolution:** Updated tree with new entries and accurate `post-create.sh` description.

### Finding: README Claude Code section omits .knowledge/
- **Severity:** nice-to-have
- **Category:** docs
- **Description:** The "Template vs. project context" table and "Memory persistence" section didn't mention `.knowledge/` files or the self-improvement loop knowledge base.
- **Resolution:** Added `.knowledge/` row to context-swap table, expanded memory section to cover both `.claude/memory/` and `.knowledge/`.

### Finding: template.json doesn't document .knowledge/ handling
- **Severity:** nice-to-have
- **Category:** template
- **Description:** `files_to_update` lists sed-substituted files but doesn't explain that `.knowledge/` is handled separately by `post-init.sh`. Confusing for template maintainers.
- **Resolution:** Added a `notes` object to `template.json` documenting the distinction.

---

<!-- Entry template:

## YYYY-MM-DD — /command-name

**Findings:** N (X critical, Y recommended, Z nice-to-have)
**Branch:** improve/YYYY-MM-DD or audit/YYYY-MM-DD
**Status:** proposed | merged | declined

### Finding: short description
- **Severity:** critical | recommended | nice-to-have
- **Category:** containerfile-health | devcontainer-config | cross-platform | ci | docs | template | security
- **Description:** what was found
- **Resolution:** how it was resolved (fill in after merge/decline)

---
-->
