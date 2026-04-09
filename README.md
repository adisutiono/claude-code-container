# Claude Code Container

A GitHub template for running [Claude Code](https://claude.ai/code) in an isolated, native container environment. Supports macOS and Windows WSL2 from a single codebase, with nested container support so Claude Code can spawn containerised workloads.

## How it works

| Platform | Runtime | VSCode connection |
|---|---|---|
| macOS 15+ | `apple/container` (Apple Virtualization.framework) | Attach to Running Apple Container |
| Windows WSL2 | Podman (native Linux, rootless) | Reopen in Container |

Both platforms use the same OCI image built from `.devcontainer/Containerfile`. Nested containers (spawned by Claude Code at runtime) run via rootless Podman inside the container — no privileged mode required.

## Prerequisites

### macOS

- macOS 15 (Sequoia) or later, Apple Silicon
- [VS Code](https://code.visualstudio.com) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- Homebrew — installed automatically by `setup.sh` if missing

### Windows WSL2

- Windows 10/11 with [WSL2 enabled](https://learn.microsoft.com/en-us/windows/wsl/install)
- A WSL2 distro (Ubuntu 22.04+ recommended)
- [VS Code](https://code.visualstudio.com) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension installed on the **Windows** side

---

## Using this template

### 1. Create your repo from this template

**GitHub UI:** click **"Use this template" → "Create a new repository"** at the top of this page.

**GitHub CLI:**
```bash
gh repo create my-project --template adisutiono/claude-code-container --clone
cd my-project
```

### 2. Install prerequisites

Run once per machine:

```bash
bash setup.sh
```

This detects your OS and:
- **macOS** — installs `apple/container` via Homebrew, enables the experimental Apple Container support in VS Code
- **WSL2** — installs Podman, configures user namespace mappings for nested containers, enables the Podman socket

### 3. Build the container image

```bash
make build
```

### 4. Start your environment

**macOS:**
```bash
make run
```
Then in VS Code: `Command Palette (⇧⌘P)` → **"Dev Containers: Attach to Running Apple Container..."** → select `claude-code-env`.

**WSL2:**
Open this folder in VS Code and choose **"Reopen in Container"** when prompted, or run `Command Palette` → **"Dev Containers: Reopen in Container"**.

---

## Daily workflow

| Command | Description |
|---|---|
| `make run` | (macOS) Start the container |
| `make stop` | (macOS) Stop the container |
| `make status` | Show runtime and container state |
| `make build` | Rebuild the image after `Containerfile` changes |
| `make clean` | Remove the image and stop the container |

---

## Customising the environment

### Add tools to the image

Edit `.devcontainer/Containerfile`. The key sections are clearly commented. Rebuild with `make build` after changes.

### Change resource limits (macOS)

`scripts/macos/run.sh` passes resource flags to `container run`. Edit `CLAUDE_MACHINE_CPUS`, `CLAUDE_MACHINE_MEMORY` etc. via environment variables or directly in the script.

### Add VS Code extensions

Add extension IDs to the `customizations.vscode.extensions` array in `.devcontainer/devcontainer.json`.

### Expose ports

Add port numbers to `forwardPorts` in `.devcontainer/devcontainer.json`.

---

## Claude Code configuration

The `.claude/` directory contains Claude Code's runtime configuration: tool permissions, slash commands, memory files, and project intelligence (`CLAUDE.md`). These are symlinked into `~/.claude/` at container start so edits take effect immediately.

### Template vs. project context

This repo is both a GitHub template and an active project. The Claude Code configuration files in the repo contain detailed template-development context (dual-platform architecture, credential flow, nested container internals). When you instantiate a new project from this template, that context is **automatically replaced** with minimal, project-appropriate versions:

| File | Template version | After instantiation |
|---|---|---|
| `CLAUDE.md` | Full architecture docs (~140 lines) | Project overview + commands (~38 lines) |
| `.claude/CLAUDE.md` | Template intelligence (~106 lines) | Coding conventions + permissions (~50 lines) |
| `.claude/settings.json` | Template-dev permissions + `model: opus` | Generic permissions, no model lock |
| `.claude/memory/` | Template project context | Cleared (blank slate) |
| `.claude/commands/init-project.md` | Present | Removed (not needed post-init) |
| `.knowledge/*.md` | Template findings | Reset to empty starters |

Generic slash commands (`/improve-repo`, `/add-toolchain`, `/audit-security`, `/update-deps`) are preserved — they work for any container-based project.

The project-starter versions live in `template/` (`project-CLAUDE.md`, `project-claude-inner.md`, `project-settings.json`) and are installed by `template/hooks/post-init.sh` during instantiation.

### Memory and knowledge persistence

Claude Code memory is committed to `.claude/memory/` so context survives container rebuilds and travels across machines.

The `.knowledge/` directory stores structured findings from the self-improvement loop. The slash commands (`/improve-repo`, `/audit-security`, `/update-deps`, `/add-toolchain`) read existing knowledge before auditing — skipping already-known issues — and write findings back after completing, building institutional knowledge across sessions.

A pre-commit hook scans both `.claude/memory/` and `.knowledge/` for secrets and blocks the commit if any are found. **Never store credentials in these files.**

---

## Project structure

```
.
├── setup.sh                          # Bootstrap: detects OS, installs runtime
├── Makefile                          # build / run / stop / status / clean
├── CLAUDE.md                         # Claude Code context (template version)
├── scripts/
│   ├── detect-os.sh                  # Exports $DETECTED_OS (macos | wsl2)
│   ├── hooks/
│   │   └── pre-commit                # Secret scanner: blocks commits with credentials in memory/knowledge files
│   ├── macos/
│   │   ├── install.sh                # Installs apple/container, patches VSCode settings
│   │   └── run.sh                    # Starts the container (apple/container run)
│   └── wsl2/
│       └── install.sh                # Installs Podman, configures subuid/gid, socket
├── .claude/
│   ├── CLAUDE.md                     # Claude Code project intelligence (template version)
│   ├── settings.json                 # Tool permissions (template version)
│   ├── memory/                       # Persistent session context (committed to git)
│   └── commands/                     # Slash commands (/improve-repo, /add-toolchain, etc.)
├── .knowledge/
│   ├── README.md                     # Schema and conventions for knowledge files
│   ├── audit-log.md                  # Cumulative findings from /improve-repo and /audit-security
│   ├── dependency-manifest.md        # Tracked dependency versions (maintained by /update-deps)
│   ├── security-findings.md          # Security findings with lifecycle tracking
│   └── toolchain-history.md          # Record of toolchain additions (/add-toolchain)
├── template/
│   ├── template.json                 # Variable schema for template instantiation
│   ├── hooks/post-init.sh            # Runs on instantiation: renames, swaps config, resets knowledge
│   ├── project-CLAUDE.md             # Root CLAUDE.md installed in new projects
│   ├── project-claude-inner.md       # .claude/CLAUDE.md installed in new projects
│   └── project-settings.json         # .claude/settings.json installed in new projects
└── .devcontainer/
    ├── devcontainer.json             # VSCode Dev Containers config (WSL2 lifecycle + shared extensions)
    ├── Containerfile                 # Ubuntu 25.10 + Claude Code (native) + rootless Podman
    ├── config/
    │   ├── containers.conf           # Podman engine config (cgroupfs, file events)
    │   └── storage.conf              # fuse-overlayfs storage driver for nested containers
    └── scripts/
        ├── post-create.sh            # Copies credentials, wires .claude/ symlinks, starts credential watcher
        └── credential-watcher.sh     # Watches /run/host-secrets/ and auto-copies updated credentials
```

---

## Nested containers

Claude Code can spawn containers at runtime (e.g. to run sandboxed builds or tests). This is handled by rootless Podman installed inside the devcontainer image.

- **macOS**: the outer container is a Linux VM (Virtualization.framework), so Podman runs inside a real Linux kernel — no restrictions.
- **WSL2**: user namespace mappings (`/etc/subuid`, `/etc/subgid`) are configured by `setup.sh`, and `fuse-overlayfs` is used as the storage driver.

No extra configuration is needed. The `post-create.sh` script runs a smoke test on first open to confirm nested containers are working.

---

## Troubleshooting

**`make build` fails on macOS with "command not found: container"**
Run `make setup` first. If `apple/container` was just installed, open a new terminal so the PATH update takes effect.

**VSCode doesn't show "Attach to Running Apple Container"**
Check that `dev.containers.experimentalAppleContainerSupport` is `true` in your VS Code user settings. `setup.sh` sets this automatically, but it targets the stable VS Code build. If you use VS Code Insiders, re-run `setup.sh`.

**Nested container smoke test fails on WSL2**
Verify `/etc/subuid` and `/etc/subgid` contain an entry for your user:
```bash
grep "$(whoami)" /etc/subuid /etc/subgid
```
If missing, re-run `bash setup.sh`.

**Podman socket not found on WSL2**
Your distro may not have systemd enabled. Run:
```bash
systemctl --user status podman.socket
```
If systemd is unavailable, `setup.sh` falls back to starting the socket directly — restart your WSL2 session and try again.
