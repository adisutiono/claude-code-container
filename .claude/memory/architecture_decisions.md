---
name: architecture_decisions
description: Key architectural decisions made and their rationale
type: project
---

Key decisions made during development — do not change without discussion:

1. **Native binary install** (`curl https://claude.ai/install.sh | bash`) instead of
   `npm install -g @anthropic-ai/claude-code`. Node.js is no longer in the base image.
   Symlink `/usr/local/bin/claude` → `~/.local/bin/claude` so VS Code extension finds it.

2. **Credential staging via `/run/host-secrets/`**: Host credentials are bind-mounted
   read-only, then copied to writable locations by postCreateCommand/run.sh.
   Copies: `.credentials.json`, `settings.json`, `sessions/`.

3. **subuid/subgid range is 131072** (not 65536): avoids triple-mapping overlap bug
   where the third Podman namespace mapping wraps back to a duplicate host UID.

4. **runArgs for WSL2 nested containers**: must include `--device /dev/net/tun`,
   `--cap-add SETUID`, `--cap-add SETGID` in addition to seccomp/apparmor opts.

5. **Memory in git** (`.claude/memory/`): symlinked from `~/.claude/projects/-workspaces-<name>/memory/`
   (path derived dynamically from `$PWD` in post-create.sh) so Claude Code writes land in the
   workspace and get committed. Pre-commit hook scans for secrets.

6. **macOS attach model gap**: `postCreateCommand` does NOT run on macOS — all lifecycle
   steps (credential copy, symlink setup, Podman init) run via `container exec` in `run.sh`.
   Workspace is mounted to `/workspaces/<name>` to match WSL2 Dev Containers default.
   `container exec --workdir` sets CWD so `post-create.sh` uses `$PWD` correctly.

**How to apply:** Before any change, check if it affects both platforms. If touching
credential flow or container lifecycle, update both devcontainer.json and run.sh.
