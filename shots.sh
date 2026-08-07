#!/usr/bin/env bash
# Take the game's named screenshots, and check them against their goldens.
#
#   ./shots.sh list                  what shots exist
#   ./shots.sh capture               render all of them into .shots/, full size
#   ./shots.sh capture world-noon    render one
#   ./shots.sh check                 compare against tests/golden/, non-zero on change
#   ./shots.sh bless world-noon      accept what is rendered as the new golden
#
# Not part of run_tests.sh, and it cannot be: --headless has no rendering device,
# so root.get_texture() returns null and the run dies several frames later on a
# null parameter. The suite covers the logic (ImageDiff, FrameStats,
# RenderBudget, ShotConfig); this covers the pixels, and it needs a display.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_ROOT="${GAMES_ROOT:-$(cd "$PROJECT_DIR/../.." && pwd)}"
VERSION="$(cat "$PROJECT_DIR/.godot-version")"
GODOT="${GODOT:-$GAMES_ROOT/engine/$VERSION/godot}"

[[ -x "$GODOT" ]] || { echo "Godot $VERSION not installed -- run toolkit/bootstrap.sh" >&2; exit 1; }

# Same reason as run_tests.sh: a class cache older than a script it has never
# seen fails at parse time as "Identifier not declared".
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

# --fixed-fps is the whole reason a shot is repeatable. Without it every frame
# advances by however long the last one really took, so animation, particles and
# the sun land somewhere slightly different on a busy machine -- and a golden
# then fails for the crime of the desktop being busy.
#
# --resolution is the *window*, which the shots do not render into: each one
# renders into its own SubViewport at its own size. It is small on purpose, so
# the window that has to exist is not also a 21-megapixel one. That decoupling
# is half of the fix for the 6K finding in GRAPHICS.md.
exec "$GODOT" \
  --path "$PROJECT_DIR" \
  --script tools/shoot.gd \
  --resolution 480x270 \
  --fixed-fps 60 \
  -- "$@"
