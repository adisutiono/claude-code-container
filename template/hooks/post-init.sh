#!/usr/bin/env bash
# Runs after template instantiation to apply variable substitutions.
# Called by: scripts/init-from-template.sh or the /init-project slash command.
set -euo pipefail

PROJECT_NAME="${1:?Usage: post-init.sh <project-name> [language] [extensions] [ports] [packages]}"
PRIMARY_LANGUAGE="${2:-none}"
VSCODE_EXTENSIONS="${3:-}"    # comma-separated extension IDs
FORWARDED_PORTS="${4:-}"      # comma-separated port numbers
EXTRA_PACKAGES="${5:-}"       # comma-separated apt package names

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> Initialising '${PROJECT_NAME}' from template..."

# ── Makefile ──────────────────────────────────────────────────────────────────
sed -i.bak \
  -e "s|IMAGE_TAG        ?= claude-code-devcontainer:latest|IMAGE_TAG        ?= ${PROJECT_NAME}:latest|" \
  -e "s|CONTAINER_NAME   ?= claude-code-env|CONTAINER_NAME   ?= ${PROJECT_NAME}-env|" \
  "${REPO_ROOT}/Makefile"
rm -f "${REPO_ROOT}/Makefile.bak"
echo "    Updated Makefile"

# ── devcontainer.json ─────────────────────────────────────────────────────────
# Use python3 with proper argument passing (no string interpolation into code)
python3 - "${REPO_ROOT}/.devcontainer/devcontainer.json" "${PROJECT_NAME}" "${VSCODE_EXTENSIONS}" "${FORWARDED_PORTS}" <<'PYEOF'
import sys, re

path, project_name, extensions_csv, ports_csv = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(path) as f:
    content = f.read()

# Replace container name
content = content.replace('"Claude Code"', f'"{project_name}"', 1)

# Add VS Code extensions (insert before the closing bracket of the extensions array)
if extensions_csv:
    ext_ids = [e.strip() for e in extensions_csv.split(",") if e.strip()]
    if ext_ids:
        ext_entries = ",\n        ".join(f'"{eid}"' for eid in ext_ids)
        content = content.replace(
            '"anthropic.claude-code"',
            f'"anthropic.claude-code",\n        {ext_entries}'
        )

# Add forwarded ports
if ports_csv:
    ports = [p.strip() for p in ports_csv.split(",") if p.strip()]
    if ports:
        port_list = ", ".join(ports)
        content = content.replace('"forwardPorts": []', f'"forwardPorts": [{port_list}]')

with open(path, "w") as f:
    f.write(content)
print("    Updated devcontainer.json")
PYEOF

# ── Containerfile: extra apt packages ─────────────────────────────────────────
if [[ -n "${EXTRA_PACKAGES}" ]]; then
  # Convert comma-separated to space-separated
  PKGS="${EXTRA_PACKAGES//,/ }"
  # Append a new RUN layer for user-requested packages
  cat >> "${REPO_ROOT}/.devcontainer/Containerfile" <<EOF

# ── Additional packages (added by template init) ─────────────────────────────
RUN apt-get update && apt-get install -y \\
    ${PKGS} \\
    && rm -rf /var/lib/apt/lists/*
EOF
  echo "    Added packages to Containerfile: ${PKGS}"
fi

# ── Containerfile: language-specific setup ────────────────────────────────────
case "${PRIMARY_LANGUAGE}" in
  python)
    cat >> "${REPO_ROOT}/.devcontainer/Containerfile" <<'EOF'

# ── Python runtime (added by template init) ───────────────────────────────────
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*
EOF
    echo "    Added Python to Containerfile"
    ;;
  rust)
    cat >> "${REPO_ROOT}/.devcontainer/Containerfile" <<'EOF'

# ── Rust toolchain (added by template init) ───────────────────────────────────
USER claude
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && echo 'source "$HOME/.cargo/env"' >> "$HOME/.zshrc"
EOF
    echo "    Added Rust to Containerfile"
    ;;
  go)
    cat >> "${REPO_ROOT}/.devcontainer/Containerfile" <<'EOF'

# ── Go runtime (added by template init) ───────────────────────────────────────
ARG GO_VERSION=1.22.2
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
    | tar -C /usr/local -xzf - \
    && echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> /home/claude/.zshrc
EOF
    echo "    Added Go to Containerfile"
    ;;
  java)
    cat >> "${REPO_ROOT}/.devcontainer/Containerfile" <<'EOF'

# ── Java runtime (added by template init) ─────────────────────────────────────
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk-headless \
    maven \
    && rm -rf /var/lib/apt/lists/*
EOF
    echo "    Added Java to Containerfile"
    ;;
  dotnet)
    cat >> "${REPO_ROOT}/.devcontainer/Containerfile" <<'EOF'

# ── .NET SDK (added by template init) ─────────────────────────────────────────
RUN apt-get update && apt-get install -y dotnet-sdk-8.0 \
    && rm -rf /var/lib/apt/lists/*
EOF
    echo "    Added .NET to Containerfile"
    ;;
  node)
    echo "    Node.js already included in base image"
    ;;
  none|"")
    echo "    No additional language runtime"
    ;;
  *)
    echo "    WARNING: Unknown language '${PRIMARY_LANGUAGE}' — skipping"
    ;;
esac

# ── Create src/ directory ────────────────────────────────────────────────────
mkdir -p "${REPO_ROOT}/src"
echo "# ${PROJECT_NAME}" > "${REPO_ROOT}/src/.gitkeep"

# ── Update tests to include language checks ──────────────────────────────────
if [[ "${PRIMARY_LANGUAGE}" != "none" && "${PRIMARY_LANGUAGE}" != "" && "${PRIMARY_LANGUAGE}" != "node" ]]; then
  case "${PRIMARY_LANGUAGE}" in
    python) CHECK_CMD="python3 --version" ;;
    rust)   CHECK_CMD="rustc --version" ;;
    go)     CHECK_CMD="go version" ;;
    java)   CHECK_CMD="java --version" ;;
    dotnet) CHECK_CMD="dotnet --version" ;;
  esac
  if [[ -n "${CHECK_CMD:-}" ]]; then
    # Insert before the nested container section
    sed -i.bak "/^# ── Nested container prerequisites/i\\
check \"${PRIMARY_LANGUAGE} is installed\"         ${CHECK_CMD}" \
      "${REPO_ROOT}/tests/container-checks.sh"
    rm -f "${REPO_ROOT}/tests/container-checks.sh.bak"
    echo "    Added ${PRIMARY_LANGUAGE} check to container-checks.sh"
  fi
fi

echo ""
echo "Template initialised for '${PROJECT_NAME}'."
echo "Next steps:"
echo "  1. Update README.md with project-specific documentation"
echo "  2. Run 'make build' to build the container image"
echo "  3. Remove the template/ directory when satisfied"
