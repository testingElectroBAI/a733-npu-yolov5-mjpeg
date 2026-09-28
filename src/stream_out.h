#pragma once
// Non-blocking frame sink: pushes one JPEG per SOCK_SEQPACKET message to a Unix socket.
// Never stalls the NPU loop: slow/absent consumer => frame dropped. Reconnects lazily.
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstring>

class FrameSink {
    int fd_ = -1, tick_ = 0;
    const char* path_;
    bool connect_() {
        fd_ = socket(AF_UNIX, SOCK_SEQPACKET | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (fd_ < 0) return false;
        sockaddr_un a{}; a.sun_family = AF_UNIX;
        strncpy(a.sun_path, path_, sizeof(a.sun_path) - 1);
        if (connect(fd_, (sockaddr*)&a, sizeof a) < 0) { close(fd_); fd_ = -1; return false; }
        int sz = 1 << 20; setsockopt(fd_, SOL_SOCKET, SO_SNDBUF, &sz, sizeof sz);
        return true;
    }
public:
    explicit FrameSink(const char* p = "/tmp/yolo_frames.sock") : path_(p) {}
    ~FrameSink() { if (fd_ >= 0) close(fd_); }
    // Never blocks. true = delivered, false = dropped / not connected.
    bool push(const uint8_t* jpg, size_t n) {
        if (fd_ < 0 && ((tick_++ % 25) || !connect_())) return false;  // retry ~every 25 frames
        ssize_t r = send(fd_, jpg, n, MSG_DONTWAIT | MSG_NOSIGNAL);
        if (r == (ssize_t)n) return true;
        if (r < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) return false;  // slow consumer: drop
        close(fd_); fd_ = -1; return false;                                    // EPIPE etc: reconnect later
    }
};
