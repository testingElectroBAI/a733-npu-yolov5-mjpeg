#!/usr/bin/env bash
# Idempotent: patches an unpacked awnpu_model_zoo examples/yolov5 dir to push frames to FrameSink.
# usage: patches/apply_patch.sh /path/to/awnpu_model_zoo-*/examples/yolov5
set -euo pipefail
Z=${1:?usage: $0 <zoo>/examples/yolov5}
HERE=$(cd "$(dirname "$0")/.." && pwd)
P="$Z/yolov5_post.cpp"
[ -f "$P" ] || { echo "no $P" >&2; exit 1; }

cp "$HERE/src/stream_out.h" "$Z/stream_out.h"

if ! grep -q 'stream_out.h' "$P"; then
  sed -i '/#include "model_config.h"/a #include "stream_out.h"' "$P"
fi
if grep -q 'cv::imwrite("output_yolov5.png", image);' "$P"; then
  sed -i 's|^\(\s*\)cv::imwrite("output_yolov5.png", image);|\1{ static FrameSink g_sink; std::vector<uint8_t> jpg; cv::imencode(".jpg", image, jpg, {cv::IMWRITE_JPEG_QUALITY, 80}); g_sink.push(jpg.data(), jpg.size()); }|' "$P"
fi
[ "$(grep -c 'FrameSink\|stream_out.h' "$P")" -ge 2 ] || { echo "patch did not apply cleanly" >&2; exit 1; }

# optional: your webcam-loop diff for main.cpp (see README)
if [ -f "$HERE/patches/main_webcam.patch" ] && ! grep -q 'VideoCapture' "$Z/main.cpp"; then
  patch -N "$Z/main.cpp" < "$HERE/patches/main_webcam.patch"
fi
echo "patched $Z"
