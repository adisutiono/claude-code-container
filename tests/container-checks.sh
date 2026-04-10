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
check "inotifywait is present"         command -v inotifywait
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

# ── Workspace file permissions ────────────────────────────────────────────────
# On virtiofs mounts (Podman on macOS), host files map as root inside the
# container. post-create.sh fixes this, but we verify critical paths here.
echo "==> Workspace file permissions"
if [ "${CI:-false}" = "true" ]; then
  echo "  SKIP  workspace permissions (workspace not mounted in CI)"
else
  # Files and dirs that must be writable for day-to-day development
  check "workspace root is writable"             test -w "${PWD}"
  check ".git dir is writable"                   test -w "${PWD}/.git"
  check ".git/refs/heads is writable"            test -w "${PWD}/.git/refs/heads"
  check ".devcontainer dir is writable"          test -w "${PWD}/.devcontainer"
  check ".devcontainer/scripts dir is writable"  test -w "${PWD}/.devcontainer/scripts"
  check "Makefile is writable"                   test -w "${PWD}/Makefile"
  check "CLAUDE.md is writable"                  test -w "${PWD}/CLAUDE.md"

  # Credential dirs must be writable for token refresh
  check "$HOME/.config/gh dir is writable"       test -w "${HOME}/.config/gh"
  check "$HOME/.claude dir is writable"          test -w "${HOME}/.claude"

  # Verify we can actually create and remove a file (not just stat-based check)
  check "can create file in workspace" bash -c "f=\"\${PWD}/.permission-test-\$\$\"; touch \"\$f\" && rm \"\$f\""
  check "can create git branch" bash -c 'git branch __permission-test 2>/dev/null && git branch -d __permission-test >/dev/null 2>&1'
fi

# ── Claude Code authentication ───────────────────────────────────────────────
echo "==> Claude Code credentials"
if [ "${CI:-false}" = "true" ]; then
  echo "  SKIP  claude credentials (not configured in CI)"
else
  check "$HOME/.claude.json exists"             test -f "${HOME}/.claude.json"
  check "$HOME/.claude/.credentials.json exists" test -f "${HOME}/.claude/.credentials.json"
  check ".credentials.json is non-empty"       test -s "${HOME}/.claude/.credentials.json"
fi

# ── GitHub CLI authentication ────────────────────────────────────────────────
echo "==> GitHub CLI"
if [ "${CI:-false}" = "true" ]; then
  echo "  SKIP  gh auth (not configured in CI)"
else
  check "gh is installed"                command -v gh
  check "gh hosts.yml exists"            test -f "${HOME}/.config/gh/hosts.yml"
  # Token presence check — don't validate against API (may be rate-limited)
  check "gh hosts.yml contains token"    grep -q "oauth_token" "${HOME}/.config/gh/hosts.yml"
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
