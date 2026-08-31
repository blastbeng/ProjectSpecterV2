#!/usr/bin/env bash
# Project Specter — remote test environment controller.
# Usage:  bash tools/remote_test.sh [--restart]
# Tokens: OK | GODOT_RUNNING | HOST_OFFLINE | SYNC_FAILED | GODOT_START_FAILED
# Exit:   0 ready | 2 host offline | 3 sync failed | 4 godot start failed
# NOTE: BatchMode requires a passphrase-less key or a loaded ssh-agent.
set -u

HOST="192.168.1.29"
RUSER="blast"
KEY="${HOME}/.ssh/id_ed25519"
PROJECT="/opt/projects/ProjectSpecter"
GODOT_BIN="/usr/local/bin/godot"
PORT="6550"
SSH="ssh -i $KEY -o ConnectTimeout=6 -o BatchMode=yes $RUSER@$HOST"

echo "[1/5] Checking host $HOST ..."
if ! $SSH 'echo online' >/dev/null 2>&1; then
  echo "HOST_OFFLINE"
  exit 2
fi
echo "        host online."

if [ "${1:-}" = "--restart" ]; then
  echo "[1/5] --restart: stopping remote Godot ..."
  $SSH "pkill -f 'godot.*ProjectSpecter'" || true
  sleep 2
fi

echo "[2/5] Pulling latest code in $PROJECT ..."
OUT=$($SSH "cd $PROJECT && git pull" 2>&1); RC=$?
echo "$OUT" | sed 's/^/        /'
if [ $RC -ne 0 ]; then
  echo "[2/5] Pull failed — committing remote local state and retrying ..."
  if ! $SSH "cd $PROJECT && git add -A && git commit -m 'auto: checkpoint before sync'; git pull"; then
    if ! $SSH "cd $PROJECT && git pull --rebase"; then
      echo "SYNC_FAILED"
      exit 3
    fi
  fi
fi

echo "[3/5] Checking playtester port :$PORT ..."
if $SSH "ss -tln | grep -q ':$PORT '"; then
  echo "        Godot already listening on :$PORT (GODOT_RUNNING)"
else
  echo "[3/5] Port down — starting Godot on remote (Wayland) ..."
  $SSH "export XDG_RUNTIME_DIR=/run/user/\$(id -u); WD=\$(ls \$XDG_RUNTIME_DIR 2>/dev/null | grep -m1 '^wayland-'); export WAYLAND_DISPLAY=\${WD:-wayland-0}; nohup $GODOT_BIN --path $PROJECT >/tmp/specter_godot.log 2>&1 &"
  echo "        waiting 10s ..."; sleep 10
  if ! $SSH "ss -tln | grep -q ':$PORT '"; then
    echo "GODOT_START_FAILED — log tail:"
    $SSH "tail -n 30 /tmp/specter_godot.log"
    exit 4
  fi
fi

echo "[4/5] Remote HEAD:"
$SSH "cd $PROJECT && git log --oneline -1" | sed 's/^/        /'

echo "[5/5] READY — godot-playtester MCP can connect to $HOST:$PORT"
echo "OK"
exit 0