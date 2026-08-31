#!/usr/bin/env bash
# Project Specter — headless test runner.
# Scans tests/ for test_*.gd SceneTree scripts and runs each with godot --headless --script.
# Prints TEST_<NAME>_RESULT=PASS|FAIL per test; exit 0 only if all pass.
set -u
GODOT_BIN="${GODOT_BIN:-/usr/local/bin/godot}"
cd "$(dirname "$0")/.." || exit 3

rc=0
for t in tests/test_*.gd; do
  name="$(basename "$t" .gd)"
  out="$("$GODOT_BIN" --headless --path . --script "res://$t" 2>&1)"
  status="$?"
  echo "$out" | grep -E "TEST_[A-Z_]+_RESULT=(PASS|FAIL)" | sed 's/^/  /'
  if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
    echo "$out" | grep -E "SCRIPT ERROR|Parse Error" | sed 's/^/  /' | head -5
  fi
  if [ "$status" -ne 0 ] || echo "$out" | grep -qE "TEST_[A-Z_]+_RESULT=FAIL|SCRIPT ERROR|Parse Error"; then
    echo "  [$name] FAIL"; rc=1
  fi
done
echo "TEST_RUN_COMPLETE rc=$rc"
exit "$rc"