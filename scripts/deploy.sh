#!/usr/bin/env bash
# Run on the BUILD machine (WSL). Builds, then ships binary + server + runner to the board.
set -euo pipefail
: "${ZOO_EXAMPLE:?set ZOO_EXAMPLE=<zoo>/examples/yolov5}"
: "${BOARD:=radxa@192.168.1.35}"
HERE=$(cd "$(dirname "$0")/.." && pwd)
make -C "$ZOO_EXAMPLE/build" -j"$(nproc)"
ssh "$BOARD" 'mkdir -p ~/deploy'
scp "$ZOO_EXAMPLE/build/yolov5_demo_a733" "$HERE/server/stream_server.py" "$HERE/scripts/run_board.sh" "$BOARD:~/deploy/"
echo "deployed -> $BOARD:~/deploy  (then on board: cd ~/deploy && ./run_board.sh)"
