# Architecture

## Overview

This repository provides a containerised development environment for Claude Code that works identically on macOS (Apple Silicon) and Windows (WSL2). The design prioritises isolation, portability, and the ability for Claude Code to spawn nested containers for sandboxed workloads.

## Design Principles

1. **No Docker**: The stack is entirely Docker-free. This avoids Docker Desktop licensing, reduces resource overhead, and leverages platform-native virtualisation.
2. **Platform-native runtimes**: macOS uses Apple's `container` CLI (Virtualization.framework); WSL2 uses Podman (rootless, daemonless). These are the lightest-weight options for each platform.
3. **Single image, two lifecycles**: Both platforms build the same OCI image from the same Containerfile. The difference is how the container is started and how VS Code connects to it.
4. **Credentials stay on the host**: Authentication tokens are never baked into the image. They're mounted read-only at runtime and copied into writable locations inside the container.
5. **Nested containers without privilege escalation**: Inner Podman runs rootless with user namespace remapping. No `--privileged` flag is used outside of CI.

## Runtime Models

### macOS (Attach Model)

```
Host (macOS)
  └── apple/container VM (Virtualization.framework)
       └── Ubuntu container (our Containerfile)
            ├── Claude Code (native binary)
            └── Podman (rootless) → nested containers
```

The container is a lightweight Linux VM. `make run` starts it; VS Code attaches to the running container. The `postCreateCommand` in `devcontainer.json` does NOT run in this model — credential setup is handled by `scripts/macos/run.sh`.

### WSL2 (Reopen Model)

```
Host (Windows)
  └── WSL2 (Linux kernel)
       └── Podman (rootless, via socket)
            └── Ubuntu container (our Containerfile)
                 ├── Claude Code (native binary)
                 └── Podman (rootless) → nested containers
```

VS Code uses the Dev Containers extension to build and start the container via the Podman socket. The `postCreateCommand` runs automatically after container creation.

## Credential Flow

```
Host credentials (read-only)
  ~/.claude.json        → /run/host-secrets/claude.json    → copied to ~/.claude.json (rw)
  ~/.claude/            → /run/host-secrets/claude-dir/    → selective copy to ~/.claude/
  ~/.gitconfig          → /run/host-secrets/gitconfig      → copied to ~/.gitconfig
  ~/.config/gh/         → /home/claude/.config/gh/ (direct mount, ro)
```

The `/run/host-secrets/` staging area exists because direct bind mounts of individual files have portability issues across container runtimes (UID mapping, filesystem notifications). The copy-on-create pattern is more reliable.

## Nested Container Architecture

The inner Podman is configured for rootless operation inside an already-namespaced environment:

- **User namespace**: `keep-id` mapping avoids double-remapping conflicts
- **Storage**: `fuse-overlayfs` (kernel overlay not available in user namespaces)
- **Network**: `slirp4netns` (doesn't require `/dev/net/tun` access)
- **Cgroup**: `cgroupfs` manager (no systemd inside the container)
- **subuid/subgid**: 131072 range to avoid the triple-mapping overlap bug

## Context Persistence

Claude Code writes project memory to `~/.claude/projects/<path>/memory/`. Inside the
container the workspace path is `/workspaces/<project-name>`, so the project directory is
`~/.claude/projects/-workspaces-<project-name>/`. At container start, `post-create.sh` (WSL2) or
`run.sh` (macOS) creates a symlink:

```
~/.claude/projects/-workspaces-<project-name>/memory/ → /workspaces/<project-name>/.claude/memory/
```

This means memory files land in the git workspace. They are committed to the repo,
making context portable across machines and container rebuilds. A pre-commit hook
(`scripts/hooks/pre-commit`) scans memory files for potential secrets before allowing
the commit.

```
Container rebuild          Clone on new machine
     │                           │
     ▼                           ▼
git checkout                git clone
     │                           │
     ▼                           ▼
.claude/memory/ intact     .claude/memory/ intact
     │                           │
     ▼                           ▼
post-create.sh symlinks    post-create.sh symlinks
     │                           │
     ▼                           ▼
Claude Code reads memory   Claude Code reads memory
```

## Security Model

See [SANDBOX-MODEL.md](SANDBOX-MODEL.md) for the full isolation and threat model.

## Template System

This repo serves as a GitHub Template Repository. After instantiation:

1. The `/init-project` Claude Code slash command customises names, packages, and extensions.
2. `template/template.json` defines the variable schema.
3. `template/hooks/post-init.sh` performs the substitutions.
4. The `template/` directory can be removed after initialisation.

### Context Separation

The template repo carries rich Claude Code configuration for its own development (dual-platform
architecture, credential flow, nested container internals). This context is irrelevant to
instantiated projects, so `post-init.sh` swaps it out:

```
Template repo (development)              Instantiated project
─────────────────────────────            ─────────────────────
CLAUDE.md (140 lines)              →     template/project-CLAUDE.md (~38 lines)
.claude/CLAUDE.md (106 lines)      →     template/project-claude-inner.md (~50 lines)
.claude/settings.json (model+deny) →     template/project-settings.json (generic)
.claude/memory/*.md                →     cleared (blank MEMORY.md index)
.claude/commands/init-project.md   →     removed
```

The swap uses the same pattern as memory cleanup: project-starter files live in `template/`
and are installed by `sed` substitution (replacing `{{PROJECT_NAME}}`). Generic slash commands
(`/improve-repo`, `/add-toolchain`, `/audit-security`, `/update-deps`) are preserved.

**To modify the project-starter context**, edit the files in `template/`:
- `template/project-CLAUDE.md` — root CLAUDE.md for new projects
- `template/project-claude-inner.md` — `.claude/CLAUDE.md` for new projects
- `template/project-settings.json` — `.claude/settings.json` for new projects

**To modify the template's own context**, edit the files in place:
- `CLAUDE.md` — root CLAUDE.md (this repo's development context)
- `.claude/CLAUDE.md` — project intelligence for template development
- `.claude/settings.json` — tool permissions for template development
