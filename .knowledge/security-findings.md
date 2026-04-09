---
type: knowledge
category: security-findings
last_updated: 2026-04-09
schema_version: 1
---

# Security Findings

Active security findings with lifecycle tracking, maintained by `/audit-security`.
Entries are prepended (newest first).

## SEC-001: /dev/net/tun runArg has wrong comment and may be unnecessary

- **Status:** mitigated
- **Severity:** MEDIUM
- **Found:** 2026-04-09
- **Resolved:** 2026-04-09
- **Description:** `devcontainer.json` comment said `--device /dev/net/tun` "enables fuse-overlayfs for nested Podman" — incorrect. `/dev/net/tun` provides TUN/TAP networking, not fuse-overlayfs. `containers.conf` configures `slirp4netns` which does not require `/dev/tun`.
- **Remediation:** Remove `--device /dev/net/tun` from runArgs; remove `chmod 666 /dev/net/tun` from post-create.sh; fix architecture_decisions.md memory entry.
- **Resolution:** Removed `/dev/net/tun` from `devcontainer.json` runArgs and `post-create.sh`. Added explanatory comment documenting slirp4netns as the reason. Fixed memory file (architecture_decisions.md point 4). Branch: fix/sec-001-remove-dev-net-tun.

---

## SEC-002: zsh-in-docker install script fetched without SHA verification

- **Status:** open
- **Severity:** LOW
- **Found:** 2026-04-09
- **Resolved:** —
- **Description:** `Containerfile` downloads `zsh-in-docker.sh` from a GitHub release (`v1.2.0`) over HTTPS and pipes it directly to `sh`. No SHA-256 checksum is verified. If the GitHub release is tampered or the download is intercepted, malicious code runs at image build time as the `claude` user.
- **Remediation:** Add SHA-256 verification after download, or use `ADD` with a pinned digest. Example: `wget -O zsh-in-docker.sh https://... && echo "EXPECTED_SHA256  zsh-in-docker.sh" | sha256sum -c && sh zsh-in-docker.sh`
- **Resolution:** —

---

## SEC-003: GitHub CLI keyring fetched without SHA pin

- **Status:** open
- **Severity:** LOW
- **Found:** 2026-04-09
- **Resolved:** —
- **Description:** GitHub CLI GPG keyring is downloaded from `cli.github.com` over HTTPS and installed directly. The keyring file itself is not SHA-pinned. Follows GitHub's official docs but a compromised CDN or MITM could substitute a different key, allowing an attacker to sign packages accepted by apt.
- **Remediation:** Pin the expected SHA-256 of the keyring file and verify before installation.
- **Resolution:** —

---

## SEC-004: Claude Code install script unverified

- **Status:** open
- **Severity:** LOW
- **Found:** 2026-04-09
- **Resolved:** —
- **Description:** `curl -fsSL https://claude.ai/install.sh | bash` downloads and executes a script without verifying its integrity. The script itself verifies the binary SHA-256, but the script is unverified. HTTPS from Anthropic's domain provides transport security. Risk: compromised CDN or DNS-level attack could deliver a malicious install script.
- **Remediation:** Fetch the script separately, verify a published SHA or signature, then execute. Or pin to a specific version once Anthropic provides versioned install URLs.
- **Resolution:** —

---

## SEC-005: sessions/ copy does not preserve permissions

- **Status:** open
- **Severity:** INFO
- **Found:** 2026-04-09
- **Resolved:** —
- **Description:** `credential-watcher.sh` uses `cp -r` (without `-p`) to copy `~/.claude/sessions/`. Session files receive the container default umask (644) rather than original host permissions. Not exploitable (files are inside the container, owned by `claude`), but session files may be more permissive than intended.
- **Remediation:** Change to `cp -rp` to preserve permissions.
- **Resolution:** —

---

## SEC-006: SYS_PTRACE on outer container

- **Status:** accepted
- **Severity:** INFO
- **Found:** 2026-04-09
- **Resolved:** 2026-04-09
- **Description:** `--cap-add SYS_PTRACE` in `devcontainer.json` runArgs gives all processes in the outer container the ability to trace any other process in the same container. This is appropriate for a developer environment but means a compromised Claude Code process could attach to and inspect any other process (e.g., the credential watcher).
- **Remediation:** No action — SYS_PTRACE is documented, intentional, and appropriate for a developer environment. Nested containers do not inherit it (absent from `default_capabilities` in `containers.conf`).
- **Resolution:** Accepted — appropriate trade-off for a dev environment.

---

<!-- Entry template:

## finding-id: short description

- **Status:** open | mitigated | accepted
- **Severity:** CRITICAL | HIGH | MEDIUM | LOW | INFO
- **Found:** YYYY-MM-DD
- **Resolved:** YYYY-MM-DD (if mitigated)
- **Description:** what was found
- **Remediation:** recommended fix
- **Resolution:** what was actually done (fill in when status changes)

---
-->
