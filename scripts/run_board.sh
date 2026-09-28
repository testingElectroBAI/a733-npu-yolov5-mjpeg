#!/usr/bin/env bash
# Run on the BOARD from ~/deploy. Starts the MJPEG server + NPU binary with respawn.
set -u
cd "$(dirname "$0")"
export LD_LIBRARY_PATH=.
NB=${NB:-yolov5s_rt_uint8_a733.nb}
pkill -f stream_server.py 2>/dev/null; pkill -f yolov5_demo_a733 2>/dev/null
python3 stream_server.py & SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT INT TERM
while true; do
  ./yolov5_demo_a733 -nb "$NB" -i webcam
  echo "yolov5_demo_a733 exited ($?), restarting in 1s"; sleep 1
done
