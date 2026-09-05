"""Command-line interface for the Windows-side Port NixVM v1 hooks."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence

from .diagnostics import ALLOWED_COMMANDS, DiagnosticError, run_diagnostic
from .duplex import (
    DEFAULT_HOST,
    RX_PORT,
    TX_PORT,
    HandshakeError,
    loopback_address,
    send_hello,
    serve_hello,
)


def _loopback_arg(value: str) -> str:
    try:
        return loopback_address(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="podlewindos",
        description=(
            "Windows-side Port NixVM v1 loopback duplex: Female RX handshake "
            "on 127.0.0.1:42067, Male TX handshake to 127.0.0.1:46720, and "
            "separate WindOS-triggered read-only diagnostics."
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    listen = subparsers.add_parser(
        "listen",
        help="PodleFemale RX: listen for PORT-NIXVM/1 HELLO on 127.0.0.1:42067",
    )
    listen.add_argument("--host", type=_loopback_arg, default=DEFAULT_HOST)
    listen.add_argument("--port", type=int, default=RX_PORT)
    listen.add_argument("--timeout", type=float, default=2.0)
    listen.add_argument(
        "--once",
        action="store_true",
        help="exit after the first valid handshake",
    )

    hello = subparsers.add_parser(
        "hello",
        help="PodleMale TX: send PORT-NIXVM/1 HELLO to 127.0.0.1:46720",
    )
    hello.add_argument("--host", type=_loopback_arg, default=DEFAULT_HOST)
    hello.add_argument("--port", type=int, default=TX_PORT)
    hello.add_argument("--timeout", type=float, default=2.0)

    diag = subparsers.add_parser(
        "diag",
        help="run a WindOS-triggered read-only diagnostic locally",
    )
    diag.add_argument("name", choices=ALLOWED_COMMANDS)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "listen":

            def on_listening(host: str, port: int) -> None:
                print(f"listening on {host}:{port}", flush=True)

            def on_hello() -> None:
                print("hello", flush=True)

            serve_hello(
                args.host,
                args.port,
                args.timeout,
                args.once,
                on_listening=on_listening,
                on_hello=on_hello,
            )
            return 0
        if args.command == "hello":
            send_hello(args.host, args.port, args.timeout)
            print("ack-hello")
            return 0
        print(run_diagnostic(args.name), end="")
        return 0
    except (HandshakeError, DiagnosticError, OSError, ValueError) as exc:
        print(f"podlewindos: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
