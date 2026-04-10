# Sandbox Model

## Purpose

This document describes the isolation boundaries for the Claude Code container environment. Because Claude Code operates with a higher degree of automation than typical developer tools, the sandbox model is designed to limit blast radius if something goes wrong.

## Trust Boundaries

```
┌─────────────────────────────────────────────────┐
│ Host machine (fully trusted)                    │
│  ├── Host filesystem (not accessible)           │
│  ├── Host network (accessible via NAT)          │
│  └── Credential files (read-only mount)         │
├─────────────────────────────────────────────────┤
│ Outer container (semi-trusted)                  │
│  ├── /workspaces/<project-name> (read-write)    │
│  ├── Claude Code (native binary)                │
│  ├── Git operations (within /workspace)         │
│  └── Podman (rootless, nested containers)       │
├─────────────────────────────────────────────────┤
│ Inner containers (untrusted workloads)          │
│  ├── User-namespaced (no real root)             │
│  ├── Network via slirp4netns (isolated)         │
│  └── Storage via fuse-overlayfs (isolated)      │
└─────────────────────────────────────────────────┘
```

## What the Container CAN Do

- Read and write files under `/workspaces/<project-name>`
- Execute Claude Code and any tools it invokes
- Spawn nested containers via rootless Podman
- Access the network (outbound, via NAT / slirp4netns)
- Read host credentials (Claude auth, git config, GitHub CLI)
- Install packages via apt, pip (inside the container)

## What the Container CANNOT Do

- Access host filesystem outside of explicitly mounted paths
- Modify host credentials (mounted read-only)
- Run privileged operations (no `--privileged`, rootless Podman)
- Access other containers or VMs on the host
- Survive a container stop/rebuild (ephemeral by design, except for Claude Code memory committed to `.claude/memory/` via git)
- Access host Docker/Podman daemon (no socket mount)

## Risk Mitigations

| Risk | Mitigation |
|---|---|
| Claude Code modifies critical config | `.claude/settings.json` deny list; CLAUDE.md conventions |
| Credential exfiltration | Read-only mounts; credentials are API tokens, not passwords |
| Nested container escape | User namespace isolation; no `--privileged` flag |
| Secret leak via memory files | Pre-commit hook scans `.claude/memory/` for secret patterns; blocks commit on match |
| Supply chain attack via Containerfile | Pinned base images; HTTPS-only package sources; GPG-verified repos |
| Runaway resource usage | macOS: VM resource limits in `run.sh`; WSL2: Podman cgroup limits |
| Persistent malware | Container is ephemeral; `make clean` removes the image entirely |

## Credential Lifecycle

1. Host credentials are created by the user (e.g., `claude login`, `gh auth login`)
2. On macOS, `initializeCommand` extracts Keychain-stored tokens (Claude Code, GitHub CLI) into staging files. These tokens cannot be bind-mounted — the Keychain is a macOS-only subsystem unavailable inside the Linux container.
3. At container start, credentials are mounted read-only into `/run/host-secrets/`
4. `postCreateCommand` copies them to writable locations. Keychain-staged credentials (if present) override empty filesystem copies.
5. A background credential watcher (`inotifywait`) monitors `/run/host-secrets/` for changes and auto-copies updated credentials into the container
6. Claude Code uses the writable copies (it needs write access for token refresh)
7. On container stop, writable copies are destroyed (container is ephemeral)
8. Token refresh writes go to the container-local copy, NOT back to the host

**Credential auto-refresh**: When the host rotates credentials (e.g., Claude auth token refresh), the `inotifywait`-based watcher detects the change and copies the updated file into `~/.claude/`. Log output goes to `/tmp/credential-watcher.log` inside the container.

**Implication**: Container-side token refreshes are still lost on restart. Host-side refreshes are now picked up automatically.

## Extending the Sandbox

When adding new capabilities to the container:

1. Document what new access is required and why
2. Prefer read-only mounts over read-write
3. Prefer copying credentials over direct mounts
4. Update `.claude/settings.json` if new paths should be protected
5. Update `tests/container-checks.sh` to validate the new configuration
6. Update this document
