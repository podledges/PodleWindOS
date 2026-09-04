"""Windows-side Port NixVM v1 loopback duplex and read-only diagnostics."""

from .diagnostics import (
    ALLOWED_COMMANDS,
    DiagnosticError,
    run_diagnostic,
)
from .duplex import (
    ACK_HELLO,
    HELLO,
    TX_PORT,
    RX_PORT,
    HandshakeError,
    loopback_address,
    send_hello,
    serve_hello,
)

__version__ = "0.1.0"

__all__ = [
    "ACK_HELLO",
    "ALLOWED_COMMANDS",
    "DiagnosticError",
    "HELLO",
    "HandshakeError",
    "RX_PORT",
    "TX_PORT",
    "loopback_address",
    "run_diagnostic",
    "send_hello",
    "serve_hello",
]
