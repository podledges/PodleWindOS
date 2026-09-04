from __future__ import annotations

import argparse
import socket
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from podlewindos.cli import _loopback_arg
from podlewindos.duplex import (
    ACK_HELLO,
    HELLO,
    RX_PORT,
    TX_PORT,
    HandshakeError,
    loopback_address,
    receive_line,
    send_hello,
)


class HandshakeTests(unittest.TestCase):
    def test_protocol_tokens_are_versioned_and_bounded(self) -> None:
        self.assertEqual(HELLO, b"PORT-NIXVM/1 HELLO\n")
        self.assertEqual(ACK_HELLO, b"PORT-NIXVM/1 ACK-HELLO\n")
        self.assertLessEqual(len(HELLO), 64)
        self.assertLessEqual(len(ACK_HELLO), 64)

    def test_locked_ports(self) -> None:
        self.assertEqual(RX_PORT, 42067)
        self.assertEqual(TX_PORT, 46720)
        self.assertLessEqual(RX_PORT, 65535)
        self.assertLessEqual(TX_PORT, 65535)

    def test_receive_line_rejects_oversized_input(self) -> None:
        sender, receiver = socket.socketpair()
        self.addCleanup(sender.close)
        self.addCleanup(receiver.close)
        sender.sendall(b"x" * 65)
        with self.assertRaises(HandshakeError):
            receive_line(receiver)

    def test_non_loopback_bind_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            loopback_address("0.0.0.0")
        with self.assertRaises(ValueError):
            loopback_address("192.168.1.1")
        with self.assertRaises(ValueError):
            loopback_address("::")
        with self.assertRaises(argparse.ArgumentTypeError):
            _loopback_arg("0.0.0.0")
        self.assertEqual(loopback_address("127.0.0.1"), "127.0.0.1")
        self.assertEqual(loopback_address("localhost"), "127.0.0.1")
        self.assertEqual(loopback_address("::1"), "::1")

    def test_cli_completes_hello_ack_hello(self) -> None:
        command = [
            sys.executable,
            str(ROOT / "bin" / "podlewindos"),
            "listen",
            "--port",
            "0",
            "--once",
        ]
        server = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.addCleanup(lambda: server.poll() is None and server.kill())
        assert server.stdout is not None
        listening = server.stdout.readline().strip()
        port = listening.rsplit(":", 1)[1]

        client = subprocess.run(
            [sys.executable, str(ROOT / "bin" / "podlewindos"), "hello", "--port", port],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        stdout, stderr = server.communicate(timeout=5)

        self.assertEqual(client.returncode, 0, client.stderr)
        self.assertEqual(client.stdout, "ack-hello\n")
        self.assertEqual(server.returncode, 0, stderr)
        self.assertEqual(stdout, "hello\n")

    def test_listen_ignores_invalid_then_handshakes(self) -> None:
        command = [
            sys.executable,
            str(ROOT / "bin" / "podlewindos"),
            "listen",
            "--port",
            "0",
            "--once",
        ]
        server = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.addCleanup(lambda: server.poll() is None and server.kill())
        assert server.stdout is not None
        listening = server.stdout.readline().strip()
        host, port_text = listening.removeprefix("listening on ").rsplit(":", 1)
        port = int(port_text)

        with socket.create_connection((host, port), timeout=2) as bogus:
            bogus.sendall(b"NOPE\n")

        send_hello(host, port, timeout=2)
        stdout, stderr = server.communicate(timeout=5)
        self.assertEqual(server.returncode, 0, stderr)
        self.assertEqual(stdout, "hello\n")

    def test_hello_rejects_wrong_ack(self) -> None:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            port = int(listener.getsockname()[1])

            def reply() -> None:
                connection, _ = listener.accept()
                with connection:
                    connection.recv(64)
                    connection.sendall(b"PORT-NIXVM/1 ACK\n")

            import threading

            worker = threading.Thread(target=reply)
            worker.start()
            self.addCleanup(worker.join)
            with self.assertRaises(HandshakeError):
                send_hello("127.0.0.1", port, timeout=2)


if __name__ == "__main__":
    unittest.main()
