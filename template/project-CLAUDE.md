# CLAUDE.md

## Overview

{{PROJECT_NAME}} — a containerised development environment powered by Claude Code.

The container is defined in `.devcontainer/Containerfile` (Ubuntu + Claude Code + rootless Podman). Edit that file to add packages, runtimes, or tools, then rebuild.

## Commands

```bash
# Build the container image
make build

# Show runtime and container state
make status

# Remove the image
make clean

# Run container validation checks (inside the container)
bash tests/container-checks.sh
```

## Adding Tools to the Image

Edit `.devcontainer/Containerfile` and run `make build`. The Containerfile is structured with commented sections for base packages, runtimes, and Podman config. Or use the `/add-toolchain` slash command for guided setup.

## Context Persistence

Claude Code memory is committed to the repo at `.claude/memory/`. A symlink wires the runtime memory directory to the workspace so writes persist across container rebuilds.

**Never store secrets in memory files.** Memory files are committed to git. A pre-commit hook scans for common secret patterns and blocks the commit if any are found.

## Key Documentation

- `docs/ARCHITECTURE.md` — design principles and runtime model
- `docs/SANDBOX-MODEL.md` — trust boundaries and credential lifecycle
- `docs/CONVENTIONS.md` — shell, Makefile, and documentation conventions
