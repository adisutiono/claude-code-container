# Knowledge Base

Structured, persistent knowledge produced and consumed by the self-improvement
slash commands (`/improve-repo`, `/audit-security`, `/update-deps`, `/add-toolchain`).

## Purpose

Unlike `docs/` (human-facing documentation) or `.claude/memory/` (per-user session
context), `.knowledge/` is the **loop's working memory** — cumulative findings that
slash commands read before auditing and write back after completing. This avoids
duplicate work across sessions and builds institutional knowledge over time.

## Files

| File | Owner command(s) | Content |
|---|---|---|
| `audit-log.md` | `/improve-repo`, `/audit-security` | Append-only log of audit findings |
| `dependency-manifest.md` | `/update-deps` | Tracked dependency versions and update status |
| `security-findings.md` | `/audit-security` | Security findings with lifecycle tracking |
| `toolchain-history.md` | `/add-toolchain` | Record of toolchain additions and changes |

## File format

Each file uses YAML frontmatter + structured Markdown, consistent with `.claude/memory/`:

```yaml
---
type: knowledge
category: <category>
last_updated: YYYY-MM-DD
schema_version: 1
---
```

Entries are prepended (newest first). Each entry follows the template documented
in the file's header comment.

## Conventions

- **Newest first**: prepend entries so the most recent state is at the top.
- **No secrets**: the pre-commit hook scans `.knowledge/` for secret patterns.
  Never store API keys, tokens, passwords, or credentials.
- **Dates**: use ISO 8601 (`YYYY-MM-DD`). Convert relative dates to absolute.
- **Status values**: `proposed` / `merged` / `declined` (audit-log),
  `open` / `mitigated` / `accepted` (security-findings).
- **On template instantiation**: files are reset to empty starters by `post-init.sh`.
