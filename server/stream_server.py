#!/usr/bin/env python3
"""Ingest JPEG frames from the NPU binary over a Unix SEQPACKET socket, serve as MJPEG over HTTP."""
import os, socket, threading
from flask import Flask, Response

SOCK = os.environ.get("YOLO_SOCK", "/tmp/yolo_frames.sock")
PORT = int(os.environ.get("PORT", "8090"))
app = Flask(__name__)
cond = threading.Condition()
latest = {"jpg": None, "seq": 0}

def ingest():
    if os.path.exists(SOCK): os.unlink(SOCK)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
    srv.bind(SOCK); os.chmod(SOCK, 0o666); srv.listen(1)
    while True:
        conn, _ = srv.accept()
        try:
            while (buf := conn.recv(1 << 20)):
                with cond:
                    latest["jpg"], latest["seq"] = buf, latest["seq"] + 1
                    cond.notify_all()
        finally:
            conn.close()

def gen():
    seq = 0
    while True:
        with cond:
            cond.wait_for(lambda: latest["seq"] != seq, timeout=5)
            if latest["seq"] == seq: continue
            seq, jpg = latest["seq"], latest["jpg"]
        yield b"--f\r\nContent-Type: image/jpeg\r\nContent-Length: %d\r\n\r\n%s\r\n" % (len(jpg), jpg)

@app.route("/stream.mjpeg")
def stream(): return Response(gen(), mimetype="multipart/x-mixed-replace; boundary=f")

@app.route("/")
def index(): return '<img src="/stream.mjpeg" style="max-width:100%">'

if __name__ == "__main__":
    threading.Thread(target=ingest, daemon=True).start()
    app.run("0.0.0.0", PORT, threaded=True)
