#!/usr/bin/env bash
# Project Specter — headless test runner (parallel + timeout-guarded).
#
# Why: each test boots a full Godot engine, so serial runs cost ~40 s per
# test even on fast machines (the engine start dominates, not the logic).
# Every tests/test_*.gd is an independent SceneTree process, so they
# parallelize perfectly:
#   - JOBS workers, default 1.5x CPU count (engine boots are I/O blocked);
#   - per-test watchdog (TEST_TIMEOUT, default 90 s): hung tests are killed
#     and reported FAIL/TIMEOUT instead of blocking the whole suite;
#   - --audio-driver Dummy: skips ALSA/Pulse setup headless tests never use;
#   - auto-runs one `--import` if the global class cache is missing
#     (needed after adding class_name scripts).
# Prints TEST_<NAME>_RESULT=PASS|FAIL lines; exit 0 only if all pass.
#
# Env knobs:
#   TEST_JOBS      worker count (default: nproc * 3 / 2)
#   TEST_TIMEOUT   per-test seconds (default 90)
#   TEST_GODOT_ARGS extra godot args for every test run
set -u
GODOT_BIN="${GODOT_BIN:-/usr/local/bin/godot}"
TIMEOUT="${TEST_TIMEOUT:-120}"
cd "$(dirname "$0")/.." || exit 3

if [ ! -f ".godot/global_script_class_cache.cfg" ]; then
  echo "-- class cache missing, importing once --"
  "$GODOT_BIN" --headless --import >/dev/null 2>&1
fi

JOBS="${TEST_JOBS:-$(nproc 2>/dev/null || echo 4)}"
# Cap workers: each Godot instance eats ~0.5 GB RAM; oversubscribing swaps
# and makes everything slower than serial (observed on RPi5).
[ "$JOBS" -gt 8 ] && JOBS=8
[ "$JOBS" -lt 1 ] && JOBS=1

run_one() {
  local t="$1"
  local name
  name="$(basename "$t" .gd)"
  local out status
  out="$(timeout -k 5 "$TIMEOUT" "$GODOT_BIN" --headless --path . \
      --audio-driver Dummy ${TEST_GODOT_ARGS:-} --script "res://$t" 2>&1)"
  status=$?
  if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
    echo "  [$name] TIMEOUT after ${TIMEOUT}s — test killed"
    echo "$out" | tail -4 | sed 's/^/      /'
    return 1
  fi
  if echo "$out" | grep -qE "TEST_[A-Z_]+_RESULT=FAIL|SCRIPT ERROR|Parse Error" \
      || [ "$status" -ne 0 ]; then
    echo "$out" | grep -E "TEST_[A-Z_]+_RESULT=(PASS|FAIL)" | sed 's/^/  /'
    echo "$out" | grep -E "SCRIPT ERROR|Parse Error" | head -4 | sed 's/^/      /'
    echo "  [$name] FAIL rc=$status"
    return 1
  fi
  echo "$out" | grep -E "TEST_[A-Z_]+_RESULT=PASS" | sed 's/^/  /'
  return 0
}
export -f run_one
export GODOT_BIN TIMEOUT

shopt -s nullglob
tests=(tests/test_*.gd)
if [ "${#tests[@]}" -eq 0 ]; then
  echo "no tests found in tests/"
  exit 3
fi

printf '%s\n' "${tests[@]}" | \
  xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
rc=$?
# xargs: 123 = at least one worker failed.
if [ "$rc" -eq 123 ]; then rc=1; fi
echo "TEST_RUN_COMPLETE rc=$rc (${#tests[@]} tests, $JOBS jobs, ${TIMEOUT}s timeout)"
exit "$rc"