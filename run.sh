#!/usr/bin/env bash
# Run the game with this project's pinned Godot.
#
#   ./run.sh                 # windowed
#   ./run.sh --fullscreen    # any extra args are passed through to Godot
#
# Runs the game itself, not the editor -- use `gd` for the editor.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_ROOT="${GAMES_ROOT:-$(cd "$PROJECT_DIR/../.." && pwd)}"
VERSION="$(cat "$PROJECT_DIR/.godot-version")"
GODOT="$GAMES_ROOT/engine/$VERSION/godot"

[[ -x "$GODOT" ]] || { echo "Godot $VERSION not installed -- run toolkit/bootstrap.sh" >&2; exit 1; }

# Global class names live in a cache Godot writes during import. A fresh clone
# has no cache, and a cache older than a newly added script does not know that
# script's class_name -- both fail at parse time as "Identifier not declared".
CLASS_CACHE="$PROJECT_DIR/.godot/global_script_class_cache.cfg"
needs_import() {
  [[ -f "$CLASS_CACHE" ]] || return 0
  local newer
  newer="$(find "$PROJECT_DIR" -name '*.gd' -newer "$CLASS_CACHE" \
    -not -path '*/.godot/*' -print -quit)"
  [[ -n "$newer" ]]
}

if needs_import; then
  echo "importing project (new or changed scripts)..."
  "$GODOT" --headless --editor --quit --path "$PROJECT_DIR" >/dev/null 2>&1 || true
fi

exec "$GODOT" --path "$PROJECT_DIR" "$@"
