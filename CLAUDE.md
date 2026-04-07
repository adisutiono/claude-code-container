# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a GitHub template for running Claude Code in an isolated container environment. It supports two platforms from a single codebase:

- **macOS 15+ (Apple Silicon)**: Uses `apple/container` (Virtualization.framework) — the container is a full Linux VM, so nested Podman has no restrictions.
- **Windows WSL2**: Uses rootless Podman — nested containers require user namespace mappings and `fuse-overlayfs`.

The OCI image is defined in `.devcontainer/Containerfile` (Ubuntu 25.10 + Claude Code native binary + rootless Podman). Node.js is not included by default — add it via `--language node` during template init or `/add-toolchain`.

## Commands

```bash
# First-time setup (installs runtime for your platform)
bash setup.sh    # or: make setup

# Build the container image
make build

# macOS: start container (then attach in VS Code)
make run

# macOS: stop container
make stop

# Show runtime and container state
make status

# Remove image (and stop container on macOS)
make clean

# Run container checks (must be run inside the container)
bash tests/container-checks.sh

# Instantiate as a new project from template (CLI path)
bash scripts/init-from-template.sh <project-name> [--language python] [--extensions id1,id2] [--ports 3000,8080] [--packages pkg1,pkg2]
```

CI builds via `podman build` with `--platform linux/amd64`; the macOS path uses `container build` with `--platform linux/arm64`.

## Architecture

### Platform detection

`scripts/detect-os.sh` exports `$DETECTED_OS` (`macos` or `wsl2`). The `Makefile` sources this at the top and branches all targets on `$(_OS)`.

### Two launch models

**WSL2** — standard Dev Containers lifecycle: `devcontainer.json` controls `build`, `runArgs`, `postCreateCommand`, and volume `mounts`. VS Code's "Reopen in Container" handles everything.

**macOS** — "attach" model: `make run` (`scripts/macos/run.sh`) starts the container with `apple/container run --detach … sleep infinity`, then VS Code attaches. Because `postCreateCommand` does not run in attach mode, `run.sh` manually copies credentials from `/run/host-secrets/` into the container after start.

### Credential flow

Host credentials are bind-mounted read-only into `/run/host-secrets/` and then copied to writable locations:

| Source (host) | Staging mount | Writable destination |
|---|---|---|
| `~/.claude.json` | `/run/host-secrets/claude.json` | `~/.claude.json` |
| `~/.claude/` | `/run/host-secrets/claude-dir` | `~/.claude/` (settings + sessions) |
| `~/.gitconfig` | `/run/host-secrets/gitconfig` | `~/.gitconfig` |
| `~/.config/gh` | mounted directly | `~/.config/gh` (read-only) |

On WSL2 this copy happens in `postCreateCommand` (in `devcontainer.json`). On macOS it happens in `scripts/macos/run.sh` via `container exec` as root, then chowned to `claude` (UID 1000).

### Nested container support

Rootless Podman inside the devcontainer enables Claude Code to spawn containers at runtime. Key pieces:

- `subuid`/`subgid` set to `claude:100000:131072` (131072 to avoid triple-mapping overlap with a 65536-range)
- `newuidmap`/`newgidmap` are setuid root
- `fuse-overlayfs` as the Podman storage driver (configured in `.devcontainer/config/storage.conf`)
- `post-create.sh` runs `mount --make-rshared /` and `chmod 666 /dev/fuse` to allow bind-mount propagation
- WSL2 `runArgs` in `devcontainer.json` add `--security-opt seccomp=unconfined`, `--security-opt apparmor=unconfined`, `--device /dev/fuse`
- CI skips the nested container smoke test (nested user namespaces not available on GitHub Actions standard runners)

### Adding tools to the image

Edit `.devcontainer/Containerfile` and run `make build`. The Containerfile is structured with clearly commented sections for base packages, GitHub CLI, Node.js, Claude Code, and Podman config. Or use the `/add-toolchain` slash command for guided setup.

### Customising macOS resource limits

`scripts/macos/run.sh` accepts `CLAUDE_MACHINE_CPUS`, `CLAUDE_MACHINE_MEMORY`, etc. as environment variables passed to `container run`.

## Claude Code Configuration

### Permission boundaries (`.claude/settings.json`)

Claude Code's tool permissions are encoded in `.claude/settings.json` using tool-pattern format. This defines what Claude Code can do without asking — editing `src/`, `docs/`, `tests/`, and `.claude/commands/` is allowed; modifying platform scripts, container config, and CI workflows requires explicit approval.

### Slash commands (`.claude/commands/`)

| Command | Purpose |
|---|---|
| `/init-project` | Interactive project setup from template (language, extensions, ports, scaffolding) |
| `/improve-repo` | Audit repo against checklist (Containerfile health, cross-platform parity, CI coverage, docs drift, template validity) and propose changes on a branch |
| `/update-deps` | Check pinned dependencies against current releases, propose update table + diff |
| `/audit-security` | Structured security review of sandbox boundaries with severity classification |
| `/add-toolchain` | Guided process for adding new languages/tools to the container |

### Self-improvement loop

The slash commands above form a closed loop: `/improve-repo` audits the full repo, `/update-deps` keeps dependencies current, `/audit-security` verifies isolation, and `/add-toolchain` extends capabilities. Findings are proposed as branches, never committed directly to main. The `.github/ISSUE_TEMPLATE/claude-improvement.md` template provides a structured format for tracking AI-proposed changes.

## Context persistence

Claude Code memory is committed to the repo at `.claude/memory/`. At container start, `post-create.sh` symlinks `~/.claude/projects/-workspace/memory/` → `/workspace/.claude/memory/` so runtime writes land in the workspace. This makes context portable across machines and container rebuilds.

A pre-commit hook (`scripts/hooks/pre-commit`) scans memory files for secret patterns (API keys, tokens, private keys, etc.) and blocks the commit if any are found. **Never store credentials or sensitive values in memory files.**

## Template system

This repo is a GitHub Template Repository. Two instantiation paths:

- **CLI**: `bash scripts/init-from-template.sh my-project --language python --ports 8000`
- **Claude Code**: `/init-project` — interactive, asks about language/extensions/ports, scaffolds `src/`, cleans up

`template/template.json` defines the full variable schema. `template/hooks/post-init.sh` performs substitutions across `Makefile`, `devcontainer.json`, `Containerfile`, and `tests/container-checks.sh`.

## Key documentation

- `docs/ARCHITECTURE.md` — design principles, runtime models, credential flow diagrams
- `docs/SANDBOX-MODEL.md` — trust boundaries, risk mitigations, credential lifecycle
- `docs/CONVENTIONS.md` — shell, Makefile, Containerfile, documentation, and git conventions
