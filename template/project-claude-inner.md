# CLAUDE.md — Project Intelligence for Claude Code

## What This Repo Is

{{PROJECT_NAME}} — a containerised development environment with Claude Code, rootless Podman, and credential forwarding.

## Coding Conventions

- **Shell scripts**: `bash`, `set -euo pipefail`, ShellCheck clean. Use `#!/usr/bin/env bash`.
- **Comments**: Explain *why*, not *what*. Every non-obvious decision gets a comment.
- **Makefile**: GNU Make compatible (no `!=` operator — macOS ships Make 3.81).
- **Container paths**: credentials in `/run/host-secrets/`, workspace at `/workspaces/{{PROJECT_NAME}}`.
- **No hardcoded usernames**: Use `${USERNAME}` build arg or `$(whoami)` at runtime.

## What Claude Code Should and Should Not Do

### Safe to modify
- Files under `src/` or the workspace folder (project code)
- Documentation in `docs/`
- Test scripts in `tests/`
- `.claude/commands/` slash command definitions
- `.gitignore`, `.editorconfig`

### Modify with care (explain reasoning)
- `.devcontainer/devcontainer.json` — affects container lifecycle
- `.devcontainer/Containerfile` — changes affect image builds
- `Makefile` — build logic
- `.github/workflows/` — CI pipeline

### Do not modify without explicit human approval
- `.devcontainer/config/containers.conf` — Podman engine config, security-sensitive
- `.devcontainer/config/storage.conf` — storage driver config
- Security-related `runArgs` in `devcontainer.json`

## Memory Persistence

Memory files are committed to the repo at `.claude/memory/` so context is portable
across machines and survives container rebuilds. At container start, a symlink wires
`~/.claude/projects/<proj>/memory/` → `<workspaceFolder>/.claude/memory/`.

**CRITICAL: Never store secrets in memory files.** Memory files are committed to git.
Do not store API keys, tokens, passwords, private keys, credentials, connection strings,
or any sensitive values in memory content. A pre-commit hook scans for common secret
patterns and blocks the commit if any are found.

When saving memories, focus on:
- User preferences and working style
- Architectural decisions and their rationale
- Project context and goals
- Feedback on approaches (what worked, what didn't)
