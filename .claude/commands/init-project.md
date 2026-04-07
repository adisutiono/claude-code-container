# /init-project

Customise this repository after it has been instantiated from the template.

## Gather Information

Ask the user for:
1. **Project name** — used in README, container name, Makefile variables
2. **Primary language/runtime** — determines additional Containerfile packages
3. **Additional VS Code extensions** — beyond the defaults
4. **Forwarded ports** — any ports the project needs exposed
5. **Additional system packages** — anything to add to the Containerfile

## Actions

1. Update `README.md`:
   - Replace template references with project name
   - Add project-specific setup instructions
   - Remove the "Using this template" section

2. Update `.devcontainer/devcontainer.json`:
   - Set `name` to project name
   - Add requested extensions to `customizations.vscode.extensions`
   - Add requested ports to `forwardPorts`

3. Update `Makefile`:
   - Set `IMAGE_TAG` default to `<project-name>:latest`
   - Set `CONTAINER_NAME` default to `<project-name>-env`

4. Update `.devcontainer/Containerfile` (if additional packages requested):
   - Add packages to the appropriate `RUN apt-get install` layer
   - Add language-specific setup (e.g., Python venv, Rust toolchain)

5. Update `CLAUDE.md`:
   - Add project-specific context
   - Update conventions for the chosen language

6. Create initial `src/` structure appropriate for the language.

7. Remove `template/` directory (no longer needed after instantiation).

## Commit

Stage all changes and create a commit: `chore: initialise <project-name> from claude-code-container template`
