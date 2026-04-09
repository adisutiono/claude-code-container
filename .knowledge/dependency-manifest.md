---
type: knowledge
category: dependency-manifest
last_updated: 2026-04-09
schema_version: 1
---

# Dependency Manifest

Tracked dependency versions maintained by `/update-deps`. Updated after each check.

| Dependency | Current | Latest | Last Checked | Breaking Changes | Recommendation |
|---|---|---|---|---|---|
| Ubuntu base | 25.10 (Oracular Oriole) | — | 2026-04-09 | Non-LTS, 9-month support | Re-evaluate on next LTS |
| Podman | Ubuntu-packaged (25.10) | — | 2026-04-09 | — | Prefer Ubuntu repo over upstream |
| GitHub CLI (`gh`) | Ubuntu-packaged (stable PPA) | — | 2026-04-09 | — | — |
| Claude Code | Latest via install script | — | 2026-04-09 | — | Unpinned (always latest) |
| zsh-in-docker | 1.2.0 | — | 2026-04-09 | — | — |
| fuse-overlayfs | Ubuntu-packaged (25.10) | — | 2026-04-09 | — | — |
| slirp4netns | Ubuntu-packaged (25.10) | — | 2026-04-09 | — | — |
| actions/checkout | v4 | — | 2026-04-09 | — | — |

> **Note:** "Latest" column should be filled by `/update-deps` on each run.
> Entries marked "Ubuntu-packaged" track the version shipped with the base image.

## Deferred Updates

<!-- Record updates that were intentionally deferred with reasons:

### dependency-name (deferred YYYY-MM-DD)
- **Current:** version
- **Available:** version
- **Reason:** why it was deferred
- **Revisit:** when to check again

-->
