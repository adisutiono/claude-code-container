---
name: project_context
description: What this repo is and its core goals
type: project
---

This repo is a GitHub Template Repository that provides a cross-platform isolated
container environment for running Claude Code. Two platforms from one image:
- macOS 15+ Apple Silicon: `apple/container` (Virtualization.framework), attach model
- Windows WSL2: rootless Podman, reopen-in-container model

Core goals:
1. Claude Code runs fully inside the container with credentials forwarded from host
2. Nested containers work (rootless Podman inside devcontainer) for sandboxed workloads
3. Context is portable — memory committed to git, travels with repo across machines
4. Self-improving — Claude Code drives its own improvements via slash commands

**Why:** User wants Claude Code to be the primary contributor inside the devcontainer,
with context that survives rebuilds and machine changes.

**How to apply:** Every change should respect the dual-platform model. Always verify
both WSL2 (devcontainer.json lifecycle) and macOS (run.sh attach model) paths.
