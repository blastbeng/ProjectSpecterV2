#!/usr/bin/env bash
# Read a PNG screenshot and report pixel statistics (mean/max brightness),
# confirming frames are non-black and content is actually rendering.
# Usage: tools/shot_stats.sh /tmp/shot.png [min_mean_brightness]
set -u
F="${1:?usage: shot_stats.sh <png> [min_mean]}"
MIN="${2:-8}"
python3 - "$F" "$MIN" <<'EOF'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("L")
px = list(im.getdata())
mean = sum(px) / len(px)
mx = max(px)
ok = mean >= float(sys.argv[2]) and mx >= 40
print(f"{sys.argv[1]}: mean={mean:.1f} max={mx} -> {'BRIGHT' if ok else 'DARK'}")
sys.exit(0 if ok else 1)
EOF