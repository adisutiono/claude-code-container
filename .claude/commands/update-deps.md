# /update-deps

Check for and propose dependency updates across the container stack.

## Knowledge Integration

Before checking, read `.knowledge/dependency-manifest.md`:
- **Review** last check dates and known versions to avoid redundant work.
- **Carry forward** deferred updates with their reasons.
- After completing the check, **update** the dependency table and deferred updates section in `.knowledge/dependency-manifest.md`. Follow the format documented in the file.

## What to Check

1. **Base image**: Is there a newer Ubuntu LTS or point release?
2. **Node.js**: Is the NodeSource setup script pulling the latest LTS?
3. **Claude Code**: Check the latest `@anthropic-ai/claude-code` version on npm.
4. **Podman**: Is the Ubuntu-packaged version current? Are there important fixes in newer versions?
5. **GitHub CLI**: Check latest `gh` release.
6. **zsh-in-docker**: Check the `ZSH_IN_DOCKER_VERSION` ARG against releases.
7. **GitHub Actions**: Are `actions/checkout` and other actions on latest major versions?

## Rules

- Only propose LTS or stable versions, never pre-release.
- For the base image, prefer point releases over `latest` tags.
- Note any breaking changes between current and proposed versions.
- If a dependency update changes behaviour, update tests and documentation.

## Output

Present a table: | Dependency | Current | Latest | Breaking Changes | Recommendation |
Then provide the Containerfile diff for approved updates.
