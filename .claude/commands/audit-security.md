# /audit-security

Perform a security audit of the container environment and configuration.

## Check These Areas

1. **Container permissions**
   - Review `runArgs` in `devcontainer.json` — are `seccomp=unconfined` and `apparmor=unconfined` still required? Can they be narrowed?
   - Review `default_capabilities` in `containers.conf` — is each capability justified?
   - Is `SYS_PTRACE` still needed? Under what conditions?

2. **Credential handling**
   - Are credentials ever written to image layers? (`docker history` / build cache check)
   - Are `/run/host-secrets/` permissions correct (readable only by container user)?
   - Does `postCreateCommand` clean up intermediate credential state?
   - Is `.claude.json` writable in the container? (It needs to be for token refresh.)

3. **Nested container isolation**
   - What can a nested container access on the host?
   - Can a nested container escape to the outer container's namespace?
   - Are subuid/subgid ranges non-overlapping with real host users?

4. **Network exposure**
   - What ports are forwarded by default?
   - Can Claude Code open arbitrary ports?
   - Is `slirp4netns` properly isolating nested container network access?

5. **Supply chain**
   - Are base images from trusted registries?
   - Is the NodeSource script fetched over HTTPS with integrity checking?
   - Are GitHub CLI GPG keys verified?

## Output

Classify each finding as: CRITICAL / HIGH / MEDIUM / LOW / INFO.
For CRITICAL and HIGH findings, include a remediation with a code diff.
