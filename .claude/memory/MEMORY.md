# Memory Index

Memory files are committed to the repo so Claude Code context is portable across
machines and survives container rebuilds. A pre-commit hook scans for secrets.

- [project_context.md](project_context.md) — What this repo is, core goals, and why
- [architecture_decisions.md](architecture_decisions.md) — Key decisions made and rationale (native install, credential flow, nested containers, memory persistence)
- [user_preferences.md](user_preferences.md) — Branch+PR workflow, terse responses, security-conscious
