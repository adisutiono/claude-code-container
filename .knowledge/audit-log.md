---
type: knowledge
category: audit-log
last_updated: 2026-04-09
schema_version: 1
---

# Audit Log

Append-only log of findings from `/improve-repo` and `/audit-security` runs.
Entries are prepended (newest first).

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
