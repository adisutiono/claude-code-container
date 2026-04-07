#!/usr/bin/env bash
# Instantiate a new project from this template.
# This is the non-Claude-Code path — for users who want to script it.
#
# Usage:
#   bash scripts/init-from-template.sh my-project
#
# For interactive customisation, use the /init-project Claude Code command instead.
set -euo pipefail

PROJECT_NAME="${1:-}"

if [[ -z "${PROJECT_NAME}" ]]; then
  echo "Usage: bash scripts/init-from-template.sh <project-name>"
  echo ""
  echo "  project-name    Lowercase, hyphenated name (e.g. my-api-service)"
  echo ""
  echo "For interactive setup with Claude Code, use the /init-project command instead."
  exit 1
fi

# Validate project name
if [[ ! "${PROJECT_NAME}" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "error: project name must be lowercase alphanumeric with hyphens (e.g. my-project)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Run the post-init hook
bash "${REPO_ROOT}/template/hooks/post-init.sh" "${PROJECT_NAME}"

echo ""
echo "You can now remove the template/ directory:"
echo "  rm -rf template/"
echo "  git add -A && git commit -m 'chore: initialise ${PROJECT_NAME} from template'"
