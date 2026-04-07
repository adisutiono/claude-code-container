---
name: user_preferences
description: User working style and workflow preferences
type: user
---

- Always work on a feature branch and create a PR — never commit directly to main
- PRs should include a test plan checklist
- Prefers terse responses — no trailing summaries, get to the point
- When something fails in CI, fix it in the same branch and push (don't open a new PR)
- Security-conscious: asked for secret scanning before committing memory files to git
- Wants Claude Code to be self-improving and drive its own contributions inside the container

**How to apply:** Default to branching + PR for all changes. If a fix is urgent and
small (CI failure in an already-open PR), push to that branch rather than opening a new one.
