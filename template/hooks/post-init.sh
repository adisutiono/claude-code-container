#!/usr/bin/env bash
# Runs after template instantiation to apply variable substitutions.
# Called by: scripts/init-from-template.sh or the /init-project slash command.
set -euo pipefail

PROJECT_NAME="${1:?Usage: post-init.sh <project-name>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> Initialising '${PROJECT_NAME}' from template..."

# ── Makefile ──────────────────────────────────────────────────────────────────
sed -i.bak \
  -e "s|IMAGE_TAG        ?= claude-code-devcontainer:latest|IMAGE_TAG        ?= ${PROJECT_NAME}:latest|" \
  -e "s|CONTAINER_NAME   ?= claude-code-env|CONTAINER_NAME   ?= ${PROJECT_NAME}-env|" \
  "${REPO_ROOT}/Makefile"

# ── devcontainer.json ─────────────────────────────────────────────────────────
# Use python for JSON manipulation to preserve comments (jq strips them)
python3 -c "
import json, sys
path = '${REPO_ROOT}/.devcontainer/devcontainer.json'
# Read raw to preserve structure, do simple string replace for the name field
with open(path) as f:
    content = f.read()
content = content.replace('\"Claude Code\"', '\"${PROJECT_NAME}\"', 1)
with open(path, 'w') as f:
    f.write(content)
print('    Updated devcontainer.json name')
"

# ── Clean up ──────────────────────────────────────────────────────────────────
rm -f "${REPO_ROOT}/Makefile.bak"

# Create src/ directory
mkdir -p "${REPO_ROOT}/src"
echo "# ${PROJECT_NAME}" > "${REPO_ROOT}/src/.gitkeep"

echo ""
echo "Template initialised for '${PROJECT_NAME}'."
echo "Next steps:"
echo "  1. Update README.md with project-specific documentation"
echo "  2. Run 'make build' to build the container image"
echo "  3. Remove the template/ directory when satisfied"
