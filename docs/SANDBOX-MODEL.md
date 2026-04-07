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
│  ├── /workspace (read-write, project files)     │
│  ├── Claude Code (Node.js process)              │
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

- Read and write files under `/workspace`
- Execute Claude Code and any tools it invokes
- Spawn nested containers via rootless Podman
- Access the network (outbound, via NAT / slirp4netns)
- Read host credentials (Claude auth, git config, GitHub CLI)
- Install packages via apt, npm, pip (inside the container)

## What the Container CANNOT Do

- Access host filesystem outside of explicitly mounted paths
- Modify host credentials (mounted read-only)
- Run privileged operations (no `--privileged`, rootless Podman)
- Access other containers or VMs on the host
- Survive a container stop/rebuild (ephemeral by design)
- Access host Docker/Podman daemon (no socket mount)

## Risk Mitigations

| Risk | Mitigation |
|---|---|
| Claude Code modifies critical config | `.claude/settings.json` deny list; CLAUDE.md conventions |
| Credential exfiltration | Read-only mounts; credentials are API tokens, not passwords |
| Nested container escape | User namespace isolation; no `--privileged` flag |
| Supply chain attack via Containerfile | Pinned base images; HTTPS-only package sources; GPG-verified repos |
| Runaway resource usage | macOS: VM resource limits in `run.sh`; WSL2: Podman cgroup limits |
| Persistent malware | Container is ephemeral; `make clean` removes the image entirely |

## Credential Lifecycle

1. Host credentials are created by the user (e.g., `claude login`, `gh auth login`)
2. At container start, credentials are mounted read-only into `/run/host-secrets/`
3. `postCreateCommand` / `run.sh` copies them to writable locations
4. Claude Code uses the writable copies (it needs write access for token refresh)
5. On container stop, writable copies are destroyed (container is ephemeral)
6. Token refresh writes go to the container-local copy, NOT back to the host

**Implication**: If Claude Code refreshes its auth token inside the container, the refreshed token is lost on container restart. The user may need to re-authenticate. This is a deliberate trade-off for security.

## Extending the Sandbox

When adding new capabilities to the container:

1. Document what new access is required and why
2. Prefer read-only mounts over read-write
3. Prefer copying credentials over direct mounts
4. Update `.claude/settings.json` if new paths should be protected
5. Update `tests/container-checks.sh` to validate the new configuration
6. Update this document
