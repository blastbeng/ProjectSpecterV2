#!/usr/bin/env bash
# Local (RPi5 labwc) screenshot loop for Project Specter: launches the game
# (or reuses a running instance), waits for the scene to settle, captures
# frames with grim, reports brightness stats. Fallback when the remote
# playtester bridge is offline.
# Usage: tools/local_shot.sh <out_prefix> [wait_s] [grim_delay_s]
set -u
PREFIX="${1:-/tmp/specter_shot}"
WAIT="${2:-22}"
DELAY="${3:-1.0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
if ! pgrep -f "godot --path /opt/projects/ProjectSpecter" >/dev/null; then
  nohup /usr/local/bin/godot --path /opt/projects/ProjectSpecter >/tmp/specter_local.log 2>&1 &
  sleep "$WAIT"
fi
sleep "$DELAY"
grim "${PREFIX}_1.png"
sleep "$DELAY"
grim "${PREFIX}_2.png"
bash tools/shot_stats.sh "${PREFIX}_1.png" 12