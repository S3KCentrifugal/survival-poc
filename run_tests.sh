#!/usr/bin/env bash
# Run the headless test suite with this project's pinned Godot.
#
#   ./run_tests.sh
#
# Exits non-zero if any test fails, so it can gate a commit or CI step.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_ROOT="${GAMES_ROOT:-$(cd "$PROJECT_DIR/../.." && pwd)}"
VERSION="$(cat "$PROJECT_DIR/.godot-version")"
GODOT="$GAMES_ROOT/engine/$VERSION/godot"

[[ -x "$GODOT" ]] || { echo "Godot $VERSION not installed -- run toolkit/bootstrap.sh" >&2; exit 1; }

# Global class names (Board, Game, ...) only resolve once the project has been
# imported, which a fresh clone has not been.
if [[ ! -f "$PROJECT_DIR/.godot/global_script_class_cache.cfg" ]]; then
  echo "first run: importing project..."
  "$GODOT" --headless --editor --quit --path "$PROJECT_DIR" >/dev/null 2>&1 || true
fi

exec "$GODOT" --headless --path "$PROJECT_DIR" --script tests/framework/test_runner.gd
