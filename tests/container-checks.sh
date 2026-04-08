#!/usr/bin/env bash
# Runs inside the container to verify the environment is correctly configured.
# Exit code 0 = all checks passed; non-zero = one or more checks failed.
set -euo pipefail

PASS=0
FAIL=0

check() {
  local desc="$1"; shift
  local output
  if output=$("$@" 2>&1); then
    echo "  PASS  $desc"
    ((PASS++)) || true
  else
    echo "  FAIL  $desc"
    while IFS= read -r line; do echo "        ${line}"; done <<< "${output}"
    ((FAIL++)) || true
  fi
}

# ── Toolchain ─────────────────────────────────────────────────────────────────
echo "==> Toolchain"
check "claude is installed"            claude --version
check "podman is installed"            podman --version
check "fuse-overlayfs is present"      command -v fuse-overlayfs
check "slirp4netns is present"         command -v slirp4netns
check "newuidmap is present"           command -v newuidmap
check "newgidmap is present"           command -v newgidmap

# ── Nested container prerequisites ───────────────────────────────────────────
echo "==> Nested container prerequisites"
check "newuidmap is setuid root"       test -u /usr/bin/newuidmap
check "newgidmap is setuid root"       test -u /usr/bin/newgidmap
check "subuid entry exists for user"   grep -q "^$(whoami):" /etc/subuid
check "subgid entry exists for user"   grep -q "^$(whoami):" /etc/subgid

# ── Podman configuration ──────────────────────────────────────────────────────
echo "==> Podman configuration"
check "containers.conf present"        test -f "${HOME}/.config/containers/containers.conf"
check "storage.conf present"           test -f "${HOME}/.config/containers/storage.conf"

# ── Context persistence ──────────────────────────────────────────────────────
# Skipped in CI: the workspace is not mounted in CI containers, and post-create.sh
# (which sets up the symlink and installs the hook) only runs in a real devcontainer.
echo "==> Context persistence"
if [ "${CI:-false}" = "true" ]; then
  echo "  SKIP  workspace memory dir exists (workspace not mounted in CI)"
  echo "  SKIP  memory symlink is set up (post-create.sh not run in CI)"
  echo "  SKIP  memory symlink target is correct (post-create.sh not run in CI)"
  echo "  SKIP  pre-commit hook installed (post-create.sh not run in CI)"
else
  check "workspace .claude dir exists"     test -d "${PWD}/.claude"
  check "commands symlink is set up"       test -L "${HOME}/.claude/commands"
  check "settings.json symlink is set up"  test -L "${HOME}/.claude/settings.json"
  check "memory symlink is set up"         test -L "${HOME}/.claude/projects/${PWD//\//-}/memory"
  check "pre-commit hook installed"        test -x "${PWD}/.git/hooks/pre-commit"
fi

# ── Nested container smoke test ───────────────────────────────────────────────
# Skipped in CI: nested user namespaces require kernel-level support that
# GitHub Actions standard runners do not provide (newuidmap cannot remap IDs
# inside an already-restricted namespace). Run locally to validate.
echo "==> Nested container smoke test"
if [ "${CI:-false}" = "true" ]; then
  echo "  SKIP  podman info (nested namespaces not available on CI runners)"
  echo "  SKIP  podman can run alpine (nested namespaces not available on CI runners)"
else
  check "podman info succeeds"        podman info
  check "podman can run alpine"       podman run --rm docker.io/library/alpine:latest echo ok
fi

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
