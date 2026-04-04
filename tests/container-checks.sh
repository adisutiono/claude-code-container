#!/usr/bin/env bash
# Runs inside the container to verify the environment is correctly configured.
# Exit code 0 = all checks passed; non-zero = one or more checks failed.
set -euo pipefail

PASS=0
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "  PASS  $desc"
    ((PASS++)) || true
  else
    echo "  FAIL  $desc"
    ((FAIL++)) || true
  fi
}

# ── Toolchain ─────────────────────────────────────────────────────────────────
echo "==> Toolchain"
check "node is installed"              node --version
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
check "podman info succeeds"           podman info

# ── Nested container smoke test ───────────────────────────────────────────────
echo "==> Nested container smoke test"
check "podman can run alpine"          podman run --rm docker.io/library/alpine:latest echo ok

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
