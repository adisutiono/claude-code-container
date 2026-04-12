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

On macOS, Podman uses virtiofs to mount the workspace into the container. Without UID mapping, the host user's UID (e.g., 501) appears as `nobody:nogroup` inside the container, causing permission failures for git operations and file edits. On WSL2, the host UID is typically 1000, matching the container user.

`devcontainer.json` uses `--userns=keep-id:uid=${localEnv:HOST_UID:1000},gid=${localEnv:HOST_GID:1000}` in `runArgs` and the same variables in `build.args`, so the container user's UID matches the host user's UID. `initializeCommand` (`initialize-host.sh`) detects the host UID/GID and persists them in `~/.devcontainer-host-env`, which is sourced from the user's login profile (`~/.zprofile` on macOS, `~/.bash_profile` on WSL2). VS Code reads these environment variables via `${localEnv:HOST_UID}` when parsing `devcontainer.json`.

On first run, the env vars may not yet be in VS Code's process environment (defaults to 1000). After `initializeCommand` sets up the profile source, a VS Code restart + container rebuild picks up the correct UID. On WSL2 where UID is already 1000, the default always works.

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

`post-create.sh` detects these staging files and copies them into the container's writable credential locations, overriding any empty filesystem copies.

### Mid-session token refresh (macOS)

`initializeCommand` runs only at container creation. If a Claude Code token expires while the container is running and the user re-authenticates on the host, the new token lands in the Keychain — not on the filesystem — so the bind mount at `/run/host-secrets/` sees no change and the `inotifywait` watcher is not triggered.

`scripts/macos-refresh-credentials.sh` closes this gap. It re-runs the Keychain extraction on demand and writes updated staging files into `~/.claude/`. Because those files live inside the bind-mounted `~/.claude/` directory, `inotifywait` detects the write and `credential-watcher.sh` applies the new credentials within seconds — no rebuild needed.

```
User re-auths on host
       │
       ▼
make refresh-credentials (runs on host)
       │
       ├── security find-generic-password → ~/.claude/.devcontainer-credentials.json
       └── gh auth token                 → ~/.config/gh/.devcontainer-hosts.yml
                       │
                       ▼  (bind mount propagates)
              /run/host-secrets/claude-dir/.devcontainer-credentials.json
                       │
                       ▼  (inotifywait fires)
              credential-watcher.sh copies → ~/.claude/.credentials.json
```

The credential watcher checks `.devcontainer-credentials.json` after `.credentials.json` in `copy_credentials()`, so the Keychain-exported copy takes precedence over any stale filesystem copy.

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
