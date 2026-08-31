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
elif [ -n "$(find scripts tests -name '*.gd' -newer .godot/global_script_class_cache.cfg -print -quit 2>/dev/null)" ]; then
  # A .gd changed after the last import: global class_name registrations may
  # be stale ("Could not find type X" after pulls with new scripts).
  echo "-- scripts newer than class cache, importing once --"
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
# Exclude the two-process driver: launched separately via tools/net_powers_test.sh.
test_list=()
for t in "${tests[@]}"; do
  [ "$(basename "$t")" = "test_net_powers.gd" ] && continue
  test_list+=("$t")
done
tests=("${test_list[@]}")
if [ "${#tests[@]}" -eq 0 ]; then
  echo "no tests found in tests/"
  exit 3
fi

printf '%s\n' "${tests[@]}" | \
  xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
rc=$?
# xargs: 123 = at least one worker failed.
if [ "$rc" -eq 123 ]; then rc=1; fi

# Two-process net test (driver + client helper) runs separately: it binds
# ENet ports and coordinates processes, so it must not share frame pacing
# with the parallel single-process suite.
run_net_powers() {
  local out
  out="$(TEST_TIMEOUT="$TIMEOUT" bash tools/net_powers_test.sh 2>&1)"
  if echo "$out" | grep -qE "TEST_NET_POWERS_RESULT=PASS"; then
    echo "  [net_powers] PASS"
  else
    echo "$out" | sed 's/^/      /' | tail -6
    echo "  [net_powers] FAIL"
    rc=1
  fi
}
run_net_powers

echo "TEST_RUN_COMPLETE rc=$rc (${#test_list[@]} headless tests + net_powers, $JOBS jobs, ${TIMEOUT}s timeout)"
exit "$rc"