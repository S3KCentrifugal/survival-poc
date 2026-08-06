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

# Global class names (Terrain, Heightfield, ...) live in a cache Godot writes
# during import. A fresh clone has no cache -- and, just as importantly, a cache
# older than a newly added script does not know that script's class_name, which
# fails at parse time as "Identifier not declared".
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

# The runner cannot see these itself. A GDScript runtime error aborts the test
# body and returns to the runner as though the method simply finished, so the
# suite counts it as a pass -- five tests once sat broken behind an "all
# passing" for a whole feature. Leaks are here for the same reason: they have
# caught two real bugs and never failed an assertion.
#
# Deliberately narrow. Tests that provoke an ordinary `ERROR:` on purpose -- a
# corrupt settings file, a malformed packet -- must stay green, so only GDScript
# errors and leaks are fatal.
FATAL='SCRIPT ERROR|Parse Error:|instances were leaked|resources still in use'

# `|| status=$?` rather than a bare assignment: under `set -e` a failing command
# substitution aborts the script at the assignment, taking the output with it --
# so a failing run printed nothing at all, which is worse than not checking.
status=0
output="$("$GODOT" --headless --path "$PROJECT_DIR" --script tests/framework/test_runner.gd 2>&1)" \
  || status=$?
echo "$output"

if grep -qE "$FATAL" <<<"$output"; then
  echo
  echo "FAILED: the run logged a script error or leaked something. A test whose" >&2
  echo "body dies on a script error still reports as passing, so this is fatal:" >&2
  grep -nE "$FATAL" <<<"$output" | head -20 >&2
  exit 1
fi

exit "$status"
