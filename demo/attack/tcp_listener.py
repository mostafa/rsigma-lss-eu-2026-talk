#!/usr/bin/env python3
"""Accept one harmless loopback connection for the live demonstration."""

from __future__ import annotations

import socket


def main() -> None:
    with socket.create_server(("127.0.0.1", 18081)) as server:
        server.settimeout(30)
        connection, _ = server.accept()
        with connection:
            connection.recv(1024)


if __name__ == "__main__":
    main()
