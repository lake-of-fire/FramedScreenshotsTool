#!/usr/bin/env bash
# {{MARKER_START}}
set -euo pipefail

ROOT="${MISE_PROJECT_ROOT:-$(pwd)}"
TOOL_DIR=""

declare -a CANDIDATES=("{{PREFERRED_TOOL_PATH}}" "Tools/FramedScreenshots" "FramedScreenshots")
for candidate in "${CANDIDATES[@]}"; do
  if [ -d "${ROOT}/${candidate}" ]; then
    TOOL_DIR="${ROOT}/${candidate}"
    break
  fi
done

if [ "${1:-}" = "install" ]; then
  shift || true
  exec framed-screenshots-tool install-framed-screenshots-tool --workspace "${ROOT}" "$@"
fi

if [ -z "${TOOL_DIR}" ]; then
  echo "FramedScreenshots package not found. Run 'mise run {{TASK_NAME}} install' first." >&2
  exit 1
fi

if command -v framed-screenshots-tool >/dev/null 2>&1; then
  framed-screenshots-tool cache-frameit-frames --workspace "${ROOT}" >/dev/null || true
fi

if [ -d "${ROOT}/FrameItExtras" ]; then
  mapfile -d '' EXTRA_ARCHIVES < <(find "${ROOT}/FrameItExtras" -type f \( -name '*.zip' -o -name '*.png' -o -name '*.heic' \) -print0 2>/dev/null)
  if [ "${#EXTRA_ARCHIVES[@]}" -gt 0 ]; then
    FRAME_ARCHIVES=""
    for archive in "${EXTRA_ARCHIVES[@]}"; do
      archive="${archive%$'\n'}"
      archive="${archive%$'\0'}"
      if [ -z "${FRAME_ARCHIVES}" ]; then
        FRAME_ARCHIVES="${archive}"
      else
        FRAME_ARCHIVES="${FRAME_ARCHIVES}:${archive}"
      fi
    done
    export FRAMED_SCREENSHOTS_FRAME_ARCHIVES="${FRAMED_SCREENSHOTS_FRAME_ARCHIVES:+${FRAMED_SCREENSHOTS_FRAME_ARCHIVES}:}${FRAME_ARCHIVES}"
  fi
fi

export FRAMED_SCREENSHOTS_ASSET_PATHS="${ROOT}/Screenshots:${ROOT}/UITestScreenshots"
exec swift run --package-path "${TOOL_DIR}" framed-screenshots "$@"
# {{MARKER_END}}
