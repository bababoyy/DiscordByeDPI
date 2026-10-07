// SPDX-License-Identifier: MIT
#include "local_probe.h"
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

int dbd_probe_socks5(unsigned short port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return 1;
    int result = 2;
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) goto done;
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    int connected = connect(fd, (struct sockaddr *)&address, sizeof address);
    if (connected < 0) {
        if (errno != EINPROGRESS) goto done;
        struct pollfd wait = { .fd = fd, .events = POLLOUT };
        if (poll(&wait, 1, 1500) <= 0) goto done;
        int error = 0;
        socklen_t length = sizeof error;
        if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) < 0 || error) goto done;
    }
    if (fcntl(fd, F_SETFL, flags) < 0) goto done;
    struct timeval timeout = { .tv_sec = 1, .tv_usec = 500000 };
    if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof timeout) < 0 ||
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof timeout) < 0) goto done;
#ifdef SO_NOSIGPIPE
    int enabled = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof enabled) < 0) goto done;
#endif
    const unsigned char greeting[] = {5, 1, 0};
    size_t sent = 0;
    result = 3;
    while (sent < sizeof greeting) {
        int options = 0;
#ifdef MSG_NOSIGNAL
        options = MSG_NOSIGNAL;
#endif
        ssize_t size = send(fd, greeting + sent, sizeof greeting - sent, options);
        if (size < 0 && errno == EINTR) continue;
        if (size <= 0) goto done;
        sent += (size_t)size;
    }
    unsigned char response[2];
    size_t received = 0;
    while (received < sizeof response) {
        ssize_t size = recv(fd, response + received, sizeof response - received, 0);
        if (size < 0 && errno == EINTR) continue;
        if (size <= 0) goto done;
        received += (size_t)size;
    }
    result = (response[0] == 5 && response[1] == 0) ? 0 : 4;
done:
    close(fd);
    return result;
}
