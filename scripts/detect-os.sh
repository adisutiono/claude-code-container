#!/usr/bin/env bash
# Detects the host OS and exports DETECTED_OS.
# Supported values: macos | wsl2
# Exits non-zero for unsupported or too-old platforms.

_detect_os() {
  local kernel
  kernel="$(uname -s)"

  case "${kernel}" in
    Darwin*)
      local major
      major="$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)"
      if [[ -z "${major}" || "${major}" -lt 15 ]]; then
        echo "error: macOS 15 (Sequoia) or later is required. Found: $(sw_vers -productVersion 2>/dev/null || echo unknown)" >&2
        return 1
      fi
      echo "macos"
      ;;

    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        # Distinguish WSL1 from WSL2
        if uname -r | grep -qi "WSL2\|microsoft-standard-WSL2" \
           || grep -qi "WSL2" /proc/version 2>/dev/null; then
          echo "wsl2"
        else
          echo "error: WSL1 is not supported. Upgrade to WSL2: https://aka.ms/wsl2" >&2
          return 1
        fi
      else
        echo "error: plain Linux hosts are not a supported target. Use macOS 15+ or Windows WSL2." >&2
        return 1
      fi
      ;;

    *)
      echo "error: unsupported kernel '${kernel}'." >&2
      return 1
      ;;
  esac
}

DETECTED_OS="$(_detect_os)" || exit 1
export DETECTED_OS
