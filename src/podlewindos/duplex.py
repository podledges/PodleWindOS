"""Loopback-only PORT-NIXVM/1 HELLO / ACK-HELLO duplex."""

from __future__ import annotations

import ipaddress
import socket
from collections.abc import Callable

HELLO = b"PORT-NIXVM/1 HELLO\n"
ACK_HELLO = b"PORT-NIXVM/1 ACK-HELLO\n"
DEFAULT_HOST = "127.0.0.1"
RX_PORT = 42067
TX_PORT = 46720
MAX_MESSAGE_BYTES = 64


class HandshakeError(Exception):
    """The peer did not complete the expected handshake."""


def loopback_address(value: str) -> str:
    """Reject names and addresses that could expose the listener to a network."""
    if value == "localhost":
        return DEFAULT_HOST
    try:
        address = ipaddress.ip_address(value)
    except ValueError as exc:
        raise ValueError("host must be localhost or a numeric loopback address") from exc
    if not address.is_loopback:
        raise ValueError("host must be a loopback address")
    return value


def receive_line(connection: socket.socket) -> bytes:
    data = bytearray()
    while len(data) <= MAX_MESSAGE_BYTES:
        chunk = connection.recv(1)
        if not chunk:
            break
        data.extend(chunk)
        if chunk == b"\n":
            return bytes(data)
    raise HandshakeError("peer sent an incomplete or oversized message")


def send_hello(host: str, port: int, timeout: float) -> None:
    host = loopback_address(host)
    with socket.create_connection((host, port), timeout=timeout) as connection:
        connection.settimeout(timeout)
        connection.sendall(HELLO)
        if receive_line(connection) != ACK_HELLO:
            raise HandshakeError("peer did not return PORT-NIXVM/1 ACK-HELLO")


def serve_hello(
    host: str,
    port: int,
    timeout: float,
    once: bool,
    on_listening: Callable[[str, int], None] | None = None,
    on_hello: Callable[[], None] | None = None,
) -> int:
    host = loopback_address(host)
    family = socket.AF_INET6 if ":" in host else socket.AF_INET
    with socket.socket(family, socket.SOCK_STREAM) as listener:
        listener.bind((host, port))
        listener.listen(4)
        actual_port = int(listener.getsockname()[1])
        if on_listening is not None:
            on_listening(host, actual_port)

        while True:
            connection, _ = listener.accept()
            with connection:
                connection.settimeout(timeout)
                try:
                    message = receive_line(connection)
                except (HandshakeError, TimeoutError, OSError):
                    continue
                if message != HELLO:
                    continue
                try:
                    connection.sendall(ACK_HELLO)
                except OSError:
                    continue
                if on_hello is not None:
                    on_hello()
            if once:
                return actual_port
        return actual_port
