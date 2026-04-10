# Architecture

## Overview

This repository provides a containerised development environment for Claude Code that works identically on macOS (Apple Silicon) and Windows (WSL2). The design prioritises isolation, portability, and the ability for Claude Code to spawn nested containers for sandboxed workloads.

## Design Principles

1. **No Docker**: The stack is entirely Docker-free. This avoids Docker Desktop licensing, reduces resource overhead, and uses Podman (rootless, daemonless) on all platforms.
2. **Podman everywhere**: Both macOS and WSL2 use rootless Podman with the standard Dev Containers lifecycle ("Reopen in Container"). One launch model, one credential flow.
3. **Single image, one lifecycle**: Both platforms build the same OCI image from the same Containerfile and use the same `devcontainer.json` lifecycle.
4. **Credentials stay on the host**: Authentication tokens are never baked into the image. They're mounted read-only at runtime and copied into writable locations inside the container.
5. **Nested containers without privilege escalation**: Inner Podman runs rootless with user namespace remapping. No `--privileged` flag is used outside of CI.

## Runtime Model

```
Host (macOS / WSL2)
  └── Podman (rootless, via socket)
       └── Ubuntu container (our Containerfile)
            ├── Claude Code (native binary)
            └── Podman (rootless) → nested containers
```

VS Code uses the Dev Containers extension to build and start the container via the Podman socket. The `postCreateCommand` runs automatically after container creation.

### Workspace UID Mapping

On macOS, Podman uses virtiofs to mount the workspace into the container. Without UID mapping, the host user's UID (e.g., 501) appears as `root` inside the container, causing permission failures for git operations and file edits.

`devcontainer.json` includes `--userns=keep-id:uid=1000,gid=1000` in `runArgs`, which maps the host user to UID 1000 (`claude`) inside the container. This ensures workspace files appear owned by the correct user. `post-create.sh` includes a `chown`/`chmod` fallback for environments where `keep-id` is unavailable.

## Credential Flow

```
Host credentials (read-only)
  ~/.claude.json        → /run/host-secrets/claude.json    → copied to ~/.claude.json (rw)
  ~/.claude/            → /run/host-secrets/claude-dir/    → selective copy to ~/.claude/
  ~/.gitconfig          → /run/host-secrets/gitconfig      → copied to ~/.gitconfig
  ~/.config/gh/         → /run/host-secrets/gh/            → copied to ~/.config/gh/
```

Host-mounted files may be owned by a different UID (e.g. root) with mode 600. `post-create.sh` uses `sudo cp` + `chown` to handle this UID mismatch.

The `/run/host-secrets/` staging area exists because direct bind mounts of individual files have portability issues across container runtimes (UID mapping, filesystem notifications). The copy-on-create pattern is more reliable.

### macOS Keychain Extraction

On macOS, both Claude Code and GitHub CLI may store OAuth tokens in the system Keychain rather than in filesystem config files. Since the Keychain is a macOS-only subsystem, these tokens are invisible to the Linux container.

`initialize-host.sh` (runs on the host via `initializeCommand`) extracts tokens before container creation:

- **GitHub CLI**: `gh auth token` → staged to `~/.config/gh/.devcontainer-hosts.yml`
- **Claude Code**: `security find-generic-password` → staged to `~/.claude/.devcontainer-credentials.json`

`post-create.sh` detects these staging files and moves them into the container's writable credential locations, overriding any empty filesystem copies. Staging files are consumed (moved, not copied) so they don't persist.

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
`~/.claude/projects/-workspaces-<project-name>/`. At container start, `post-create.sh`
creates a symlink:

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

### Knowledge base (`.knowledge/`)

The self-improvement slash commands persist structured findings in `.knowledge/`.
Unlike memory (per-user session context), knowledge is cumulative loop output:
audit findings, dependency state, security finding lifecycle, toolchain change records.

Commands read existing knowledge before auditing (to skip known issues) and write
findings back after completing (to build institutional knowledge). On template
instantiation, `post-init.sh` resets knowledge files to empty starters.

The pre-commit hook scans `.knowledge/` for secret patterns alongside `.claude/memory/`.

## Security Model

See [SANDBOX-MODEL.md](SANDBOX-MODEL.md) for the full isolation and threat model.

## Template System

This repo serves as a GitHub Template Repository. After instantiation:

1. The `/init-project` Claude Code slash command customises names, packages, and extensions.
2. `template/template.json` defines the variable schema.
3. `template/hooks/post-init.sh` performs the substitutions.
4. The `template/` directory can be removed after initialisation.

### Context Separation

The template repo carries rich Claude Code configuration for its own development. This
context is irrelevant to instantiated projects, so `post-init.sh` swaps it out:

```
Template repo (development)              Instantiated project
─────────────────────────────            ─────────────────────
CLAUDE.md (140 lines)              →     template/project-CLAUDE.md (~38 lines)
.claude/CLAUDE.md (106 lines)      →     template/project-claude-inner.md (~50 lines)
.claude/settings.json (model+deny) →     template/project-settings.json (generic)
.claude/memory/*.md                →     cleared (blank MEMORY.md index)
.knowledge/*.md                    →     reset to empty starters
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
