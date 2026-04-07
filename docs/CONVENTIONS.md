# Conventions

## Shell Scripts

- Shebang: `#!/usr/bin/env bash`
- Always set: `set -euo pipefail`
- Quote all variable expansions: `"${VAR}"` not `$VAR`
- Use `[[ ]]` for conditionals, not `[ ]`
- Functions use lowercase with underscores: `_detect_os()`
- Exit with meaningful codes: 0 = success, 1 = user error, 2 = system error
- Log with `echo "==> Action..."` for top-level steps, `echo "    Detail..."` for sub-steps

## Makefile

- Compatible with GNU Make 3.81 (ships with macOS)
- No `:=` or `!=` operators — use `$(shell ...)` instead
- Targets are `.PHONY` unless they produce files
- Help target uses `grep -E '^## '` convention
- Variables at the top with `?=` for overridability

## Containerfile

- One concern per `RUN` layer (readability over layer count)
- Pin base image to a specific release, not `latest`
- Clean apt caches in the same `RUN` that installs: `&& rm -rf /var/lib/apt/lists/*`
- Use build args for anything that might change between builds
- Comments explain *why* each section exists

## Documentation

- Use Australian English spelling (behaviour, customise, initialise)
- Markdown files use ATX headings (`#` not underlines)
- Code blocks specify the language for syntax highlighting
- Keep lines under 100 characters where practical
- README covers *usage*; ARCHITECTURE covers *design*; this file covers *style*

## Git

- Commit messages: `type: short description` (e.g., `fix: handle missing .claude.json`)
- Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`
- One logical change per commit
- Never force-push to `main`
- PRs require CI to pass
