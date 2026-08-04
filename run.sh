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

# A fresh clone has no import cache, and the scene's scripts reference global
# class names that only resolve once the project has been imported.
if [[ ! -f "$PROJECT_DIR/.godot/global_script_class_cache.cfg" ]]; then
  echo "first run: importing project..."
  "$GODOT" --headless --editor --quit --path "$PROJECT_DIR" >/dev/null 2>&1 || true
fi

exec "$GODOT" --path "$PROJECT_DIR" "$@"
