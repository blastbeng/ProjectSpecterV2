#!/usr/bin/env bash
# Networked entity powers test (Vision 6): driver + client halves in two
# headless Godot processes on 127.0.0.1. The client joins first (wall-clock
# lifetime), the driver connects, casts powers over the wire, and prints
# TEST_NET_POWERS_RESULT=PASS|FAIL. Invoked by tools/test.sh.
#
# Env: TEST_TIMEOUT (default 120 s), GODOT_BIN.
set -u
GODOT_BIN="${GODOT_BIN:-/usr/local/bin/godot}"
TIMEOUT="${TEST_TIMEOUT:-120}"
cd "$(dirname "$0")/.." || exit 3
rm -f /tmp/specter_net_client_status.json

"$GODOT_BIN" --headless --path . --audio-driver Dummy \
  --script res://tests/net_client_helper.gd \
  > /tmp/specter_net_client.log 2>&1 &
CLIENT_PID=$!
sleep 1

"$GODOT_BIN" --headless --path . --audio-driver Dummy \
  --script res://tests/test_net_powers.gd \
  > /tmp/specter_net_driver.log 2>&1 &
DRIVER_PID=$!

wait "$DRIVER_PID"
DRV=$?

# Client exits when the driver has finished or its lifetime expires.
for i in $(seq 1 20); do
  if ! kill -0 "$CLIENT_PID" 2>/dev/null; then break; fi
  sleep 0.5
done
if kill -0 "$CLIENT_PID" 2>/dev/null; then
  kill "$CLIENT_PID" 2>/dev/null
  sleep 0.5
fi

if [ "$DRV" -eq 0 ]; then
  echo "TEST_NET_POWERS_RESULT=PASS (client log: /tmp/specter_net_client.log)"
  exit 0
fi
echo "TEST_NET_POWERS_RESULT=FAIL rc=$DRV (driver log: /tmp/specter_net_driver.log, client log: /tmp/specter_net_client.log)"
tail -6 /tmp/specter_net_driver.log 2>/dev/null | sed 's/^/    /'
echo "  -- client tail --"
tail -6 /tmp/specter_net_client.log 2>/dev/null | sed 's/^/    /'
exit 1