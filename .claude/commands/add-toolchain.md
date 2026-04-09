# /add-toolchain

Add a new language or tool to the container environment.

## Gather Information

Ask the user:
1. What tool or language to add (e.g., Python 3.12, Rust, Go, Java, .NET)
2. Whether it should be in the base image or installed at runtime

## Actions

1. **Add to Containerfile**: Insert a new clearly-commented section after the Node.js block. Follow the existing pattern:
   - Dedicated `RUN` layer with section header comment
   - Clean apt caches in the same layer
   - Pin versions where possible

2. **Add VS Code extensions**: Add relevant language extensions to `.devcontainer/devcontainer.json`

3. **Update tests**: Add toolchain presence checks to `tests/container-checks.sh`

4. **Update documentation**:
   - Add to the "Customising the environment" section in `README.md`
   - Update `CLAUDE.md` if conventions change

5. **Verify cross-platform**: Ensure the packages are available on both `linux/arm64` (macOS) and `linux/amd64` (WSL2) architectures.

## Knowledge Integration

After adding the toolchain, **prepend** an entry to `.knowledge/toolchain-history.md` recording what was added, version, files modified, and any extensions. Follow the entry template in the file.

## Do NOT

- Remove existing tools unless asked
- Change the base image
- Modify Podman or nested container configuration
