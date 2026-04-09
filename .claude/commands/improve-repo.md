# /improve-repo

Audit the repository and propose improvements. Follow this checklist:

## Knowledge Integration

Before auditing, read `.knowledge/audit-log.md` to review previous findings:
- **Skip** re-reporting issues that are already tracked and unresolved (status: `proposed`).
- **Note** if a previously declined finding recurs — mention it but do not re-propose.
- After completing the audit, **prepend** new findings to `.knowledge/audit-log.md` with the date, branch name, severity, and status `proposed`. Follow the entry template in the file.

## Audit Steps

1. **Containerfile health**
   - Is the base image pinned to a specific version? Flag if using `latest`.
   - Are there any packages that could be consolidated into fewer RUN layers?
   - Is Claude Code version pinned or using `latest`? Note the trade-off.
   - Are there any known CVEs in the base image packages?

2. **Devcontainer config**
   - Are all mounts still necessary?
   - Are `runArgs` minimal (principle of least privilege)?
   - Are forwarded ports documented?
   - Does `postCreateCommand` handle all credential scenarios gracefully?

3. **Cross-platform parity**
   - Does the macOS `run.sh` handle the same credential mounts as `devcontainer.json`?
   - Are there features available on one platform but not the other? Document gaps.

4. **CI pipeline**
   - Does the CI workflow test everything that `container-checks.sh` covers?
   - Are there untested paths (macOS-specific logic can't run in CI — is this documented)?

5. **Documentation**
   - Is `README.md` current with actual repo structure?
   - Is `CLAUDE.md` consistent with the actual codebase?
   - Is `docs/ARCHITECTURE.md` up to date?

6. **Template health**
   - Does `template/template.json` cover all customisable variables?
   - Does the init script work for a fresh instantiation?

7. **Security**
   - Are credentials never baked into the image?
   - Is `/run/host-secrets/` properly cleaned after copy?
   - Are subuid/subgid ranges adequate?

## Output

For each finding, propose a fix as a code change with explanation. Group changes into:
- **Critical** — security or correctness issues
- **Recommended** — quality-of-life or robustness improvements
- **Nice-to-have** — cosmetic or documentation tweaks

Create a new branch `improve/YYYY-MM-DD` with the changes, but do NOT push without human review.
