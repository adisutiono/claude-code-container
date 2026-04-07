#!/usr/bin/env bash
# Instantiate a new project from this template.
# This is the non-Claude-Code path — for users who want to script it.
#
# Usage:
#   bash scripts/init-from-template.sh <project-name> [options]
#
# Options:
#   --language <lang>       Primary language: node, python, rust, go, java, dotnet, none
#   --extensions <ids>      Comma-separated VS Code extension IDs
#   --ports <numbers>       Comma-separated port numbers to forward
#   --packages <names>      Comma-separated additional apt packages
#
# For interactive setup with Claude Code, use the /init-project command instead.
set -euo pipefail

PROJECT_NAME=""
LANGUAGE="none"
EXTENSIONS=""
PORTS=""
PACKAGES=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --language)  LANGUAGE="${2:?--language requires a value}"; shift 2 ;;
    --extensions) EXTENSIONS="${2:?--extensions requires a value}"; shift 2 ;;
    --ports)     PORTS="${2:?--ports requires a value}"; shift 2 ;;
    --packages)  PACKAGES="${2:?--packages requires a value}"; shift 2 ;;
    -h|--help)
      echo "Usage: bash scripts/init-from-template.sh <project-name> [options]"
      echo ""
      echo "  project-name              Lowercase, hyphenated name (e.g. my-api-service)"
      echo ""
      echo "Options:"
      echo "  --language <lang>         node, python, rust, go, java, dotnet, none (default: none)"
      echo "  --extensions <ids>        Comma-separated VS Code extension IDs"
      echo "  --ports <numbers>         Comma-separated port numbers to forward"
      echo "  --packages <names>        Comma-separated additional apt packages"
      echo ""
      echo "For interactive setup with Claude Code, use the /init-project command instead."
      exit 0
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "${PROJECT_NAME}" ]]; then
        PROJECT_NAME="$1"
      else
        echo "error: unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "${PROJECT_NAME}" ]]; then
  echo "Usage: bash scripts/init-from-template.sh <project-name> [options]"
  echo ""
  echo "Run with --help for full options."
  exit 1
fi

# Validate project name
if [[ ! "${PROJECT_NAME}" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "error: project name must be lowercase alphanumeric with hyphens (e.g. my-project)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Run the post-init hook with all variables
bash "${REPO_ROOT}/template/hooks/post-init.sh" \
  "${PROJECT_NAME}" \
  "${LANGUAGE}" \
  "${EXTENSIONS}" \
  "${PORTS}" \
  "${PACKAGES}"

echo ""
echo "You can now remove the template/ directory:"
echo "  rm -rf template/"
echo "  git add -A && git commit -m 'chore: initialise ${PROJECT_NAME} from template'"
