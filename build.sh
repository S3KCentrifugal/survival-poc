#!/usr/bin/env bash
# Build the game for every shipping platform.
#
#   ./build.sh                 # all platforms, release
#   ./build.sh linux           # one platform
#   ./build.sh --debug         # debug templates, for a tester who needs a log
#
# Exists so CI is a thin wrapper around something that can be run and fixed
# locally. A pipeline whose only home is a YAML file is a pipeline you debug by
# pushing commits.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_ROOT="${GAMES_ROOT:-$(cd "$PROJECT_DIR/../.." && pwd)}"
VERSION="$(cat "$PROJECT_DIR/.godot-version")"
GODOT="${GODOT:-$GAMES_ROOT/engine/$VERSION/godot}"
OUT_ROOT="${BUILD_OUT:-$GAMES_ROOT/exports/survival-poc}"

MODE="release"
PLATFORMS=()
for arg in "$@"; do
  case "$arg" in
    --debug) MODE="debug" ;;
    --release) MODE="release" ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) PLATFORMS+=("$arg") ;;
  esac
done
[[ ${#PLATFORMS[@]} -eq 0 ]] && PLATFORMS=(linux windows)

# Preset name -> output file. The preset names must match export_presets.cfg
# exactly; Godot matches on the string and silently exports nothing otherwise.
preset_for() { case "$1" in linux) echo "Linux" ;; windows) echo "Windows" ;; *) return 1 ;; esac; }
binary_for() { case "$1" in linux) echo "survival-poc.x86_64" ;; windows) echo "survival-poc.exe" ;; *) return 1 ;; esac; }

[[ -x "$GODOT" ]] || { echo "Godot $VERSION not found at $GODOT" >&2; exit 1; }

# Export templates are a separate 1.2 GB download from the editor and the export
# fails with a bare "no export template found" if they are missing.
TEMPLATE_DIR="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates/$VERSION.stable}"
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Export templates for $VERSION are not installed." >&2
  echo "  expected: $TEMPLATE_DIR" >&2
  echo "  get them: https://github.com/godotengine/godot/releases/download/$VERSION-stable/Godot_v$VERSION-stable_export_templates.tpz" >&2
  exit 1
fi

# The class cache again -- an export with a stale cache fails the same way a
# test run does, as "Identifier not declared".
"$GODOT" --headless --editor --quit --path "$PROJECT_DIR" >/dev/null 2>&1 || true

for platform in "${PLATFORMS[@]}"; do
  preset="$(preset_for "$platform")" || { echo "unknown platform: $platform" >&2; exit 2; }
  binary="$(binary_for "$platform")"
  out_dir="$OUT_ROOT/$platform"

  # Cleared rather than overwritten. A stale file from a previous layout would
  # otherwise be uploaded to Steam forever, because SteamPipe syncs what it is
  # given rather than what changed.
  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  echo "==> $platform ($MODE)"
  "$GODOT" --headless --path "$PROJECT_DIR" "--export-$MODE" "$preset" "$out_dir/$binary"

  [[ -s "$out_dir/$binary" ]] || { echo "export produced nothing for $platform" >&2; exit 1; }
  # Set here rather than trusted from the depot. Steam preserves the executable
  # bit it is *given*, so a Linux build uploaded from a Windows runner arrives
  # unlaunchable -- see DEPLOY.md.
  [[ "$platform" == "linux" ]] && chmod +x "$out_dir/$binary"

  echo "    $(du -h "$out_dir/$binary" | cut -f1)  $out_dir/$binary"
done

echo
echo "built into $OUT_ROOT"
