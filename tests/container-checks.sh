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
    echo "${output}" | sed 's/^/        /'
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
