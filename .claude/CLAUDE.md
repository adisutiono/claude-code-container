# CLAUDE.md — Project Intelligence for Claude Code

## What This Repo Is

This is a **GitHub template repository** that provides an isolated, cross-platform container environment for running Claude Code. It supports macOS (Apple Virtualization.framework via `apple/container`) and Windows WSL2 (rootless Podman). Nested containers are supported inside the devcontainer for sandboxed workloads.

When someone instantiates this template, they get a ready-to-use Claude Code development environment with credential forwarding, nested container support, and cross-platform tooling.

## Architecture Decisions (Do Not Change Without Discussion)

1. **Dual runtime model**: macOS uses `apple/container` (attach model), WSL2 uses Podman (reopen-in-container model). These are fundamentally different lifecycle models — do not try to unify them into one path.
2. **Credential forwarding via `/run/host-secrets/`**: Host credentials are mounted read-only, then copied to writable locations by `postCreateCommand` / `run.sh`. This avoids permission issues with UID mismatches between host and container.
3. **Nested containers via rootless Podman inside the devcontainer**: The inner Podman uses `fuse-overlayfs`, `slirp4netns`, and `keep-id` user namespace mapping. The subuid/subgid range is 131072 (not 65536) to avoid the triple-mapping overlap bug.
4. **Ubuntu base image**: Pinned to a specific release in the Containerfile. Podman packages from Ubuntu repos are preferred over upstream to avoid dependency conflicts.
5. **No Docker dependency**: The entire stack is Docker-free. WSL2 uses Podman natively; macOS uses Apple's container CLI. `DOCKER_HOST` is set to the Podman socket for tool compatibility only.

## Repository Structure

```
.claude/              → Claude Code configuration and slash commands (this layer)
.devcontainer/        → Container definition, configs, lifecycle scripts
.github/              → CI workflows, issue templates
.knowledge/           → Structured findings from the self-improvement loop
.vscode/              → Editor settings and extension recommendations
scripts/              → Platform-specific installers and runtime scripts
template/             → Template instantiation config and hooks
tests/                → Container validation checks
docs/                 → Architecture docs, sandbox model, conventions
```

## Key Files and Their Roles

- `.devcontainer/Containerfile` — the OCI image definition. Changes here require `make build`.
- `.devcontainer/devcontainer.json` — VSCode devcontainer config. `runArgs` apply to WSL2 only.
- `scripts/macos/run.sh` — starts the container on macOS and copies credentials in.
- `Makefile` — primary interface: `build`, `run`, `stop`, `status`, `clean`.
- `tests/container-checks.sh` — validates the container environment. Run in CI and locally.

## Coding Conventions

- **Shell scripts**: `bash`, `set -euo pipefail`, ShellCheck clean. Use `#!/usr/bin/env bash`.
- **Comments**: Explain *why*, not *what*. Every non-obvious decision gets a comment.
- **Makefile**: GNU Make compatible (no `!=` operator — macOS ships Make 3.81).
- **Container paths**: credentials in `/run/host-secrets/`, workspace at `/workspaces/<project-name>`.
- **No hardcoded usernames**: Use `${USERNAME}` build arg or `$(whoami)` at runtime.

## What Claude Code Should and Should Not Do

### Safe to modify
- Files under `src/` or the workspace folder (project code in instantiated repos)
- Documentation in `docs/`
- Test scripts in `tests/`
- `.claude/commands/` slash command definitions
- `.knowledge/` knowledge base files
- `.gitignore`, `.editorconfig`

### Modify with care (explain reasoning)
- `.devcontainer/devcontainer.json` — affects both platforms
- `.devcontainer/Containerfile` — changes affect image builds
- `Makefile` — cross-platform build logic
- `.github/workflows/` — CI pipeline

### Do not modify without explicit human approval
- `.devcontainer/config/containers.conf` — Podman engine config, security-sensitive
- `.devcontainer/config/storage.conf` — storage driver config
- `scripts/macos/run.sh` — macOS container lifecycle
- `scripts/wsl2/install.sh` — WSL2 system configuration
- Security-related `runArgs` in `devcontainer.json`

## Memory Persistence

Memory files are committed to the repo at `.claude/memory/` so context is portable
across machines and survives container rebuilds. At container start, a symlink wires
`~/.claude/projects/<proj>/memory/` → `<workspaceFolder>/.claude/memory/` so Claude Code's
runtime writes land directly in the workspace.

**CRITICAL: Never store secrets in memory files.** Memory files are committed to git.
Do not store API keys, tokens, passwords, private keys, credentials, connection strings,
or any sensitive values in memory content. A pre-commit hook scans for common secret
patterns and blocks the commit if any are found.

When saving memories, focus on:
- User preferences and working style
- Architectural decisions and their rationale
- Project context and goals
- Feedback on approaches (what worked, what didn't)

## Knowledge Base

The `.knowledge/` directory holds structured findings produced and consumed by the
self-improvement slash commands. Unlike `docs/` (human-facing) or `.claude/memory/`
(per-user session context), `.knowledge/` is the loop's cumulative working memory.

Commands read existing knowledge before auditing (to skip known issues and avoid
duplicate work) and write findings back after completing (to build institutional
knowledge). See `.knowledge/README.md` for the file format and conventions.

The pre-commit hook scans `.knowledge/` for secret patterns, same as `.claude/memory/`.

## Self-Improvement Guidelines

When asked to improve the repo (via `/improve-repo` or similar):
1. Always propose changes as a diff or branch — never commit directly to main.
2. Check the CI workflow passes conceptually before proposing changes.
3. Cross-platform impact: if a change affects one platform, verify it doesn't break the other.
4. Update `docs/ARCHITECTURE.md` if architectural decisions change.
5. Update this `CLAUDE.md` if conventions or structure change.
6. Prefer additive changes over modifications to working code.

## Template Variables

When this repo is used as a template, the following can be customised:
- Project name (replaces `claude-code-container` references)
- Additional Containerfile packages
- VSCode extensions
- Forwarded ports
- Claude Code permission scope

See `template/template.json` for the full variable schema.

## Context Separation (Template vs. Project)

This repo's Claude Code config (`CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/settings.json`, `.claude/memory/`) is specific to **template development**. On instantiation, `post-init.sh` swaps these with minimal project-starter versions from `template/`.

When editing Claude Code configuration, be aware of which context you're changing:

- **Template context** (this repo's development): edit `CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/settings.json` directly
- **Project-starter context** (what new projects get): edit `template/project-CLAUDE.md`, `template/project-claude-inner.md`, `template/project-settings.json`

Changes to template context do NOT propagate to instantiated projects and vice versa.
