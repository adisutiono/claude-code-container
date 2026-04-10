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
   read-only, then copied to writable locations by postCreateCommand.
   Copies: `.credentials.json`, `settings.json`, `sessions/`.
   Uses `sudo cp` + `chown` because host files may be owned by root with mode 600.

3. **subuid/subgid range is 131072** (not 65536): avoids triple-mapping overlap bug
   where the third Podman namespace mapping wraps back to a duplicate host UID.

4. **runArgs for nested containers**: must include `--device /dev/fuse`,
   `--cap-add SETUID`, `--cap-add SETGID` in addition to seccomp/apparmor opts.
   `/dev/net/tun` is NOT needed — nested containers use slirp4netns, which is
   userspace and requires no tun device. (pasta would need it; slirp4netns does not.)

5. **Memory in git** (`.claude/memory/`): symlinked from `~/.claude/projects/-workspaces-<name>/memory/`
   (path derived dynamically from `$PWD` in post-create.sh) so Claude Code writes land in the
   workspace and get committed. Pre-commit hook scans for secrets.

6. **Podman on all platforms**: Both macOS and WSL2 use rootless Podman with the standard
   Dev Containers lifecycle ("Reopen in Container"). No apple/container, no Docker.

**How to apply:** Before any change, check if it affects the devcontainer lifecycle.
If touching credential flow, update both devcontainer.json and post-create.sh.
