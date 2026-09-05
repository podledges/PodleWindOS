from __future__ import annotations

import argparse
import socket
import struct
import subprocess
import sys
import threading
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "bin" / "podlewindos"
sys.path.insert(0, str(ROOT / "src"))

from podlewindos.cli import _loopback_arg
from podlewindos.duplex import HandshakeError, loopback_address, receive_line, send_hello

FEMALE_RX = ("127.0.0.1", 42067)
MALE_TX = ("127.0.0.1", 46720)
HELLO = b"PORT-NIXVM/1 HELLO\n"
ACK_HELLO = b"PORT-NIXVM/1 ACK-HELLO\n"


def _cli(*args: str) -> list[str]:
    return [sys.executable, str(BIN), *args]


def _start_listen(*args: str) -> subprocess.Popen[str]:
    server = subprocess.Popen(
        _cli("listen", *args),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return server


def _read_line(connection: socket.socket) -> bytes:
    data = bytearray()
    while b"\n" not in data:
        chunk = connection.recv(1)
        if not chunk:
            break
        data.extend(chunk)
    return bytes(data)


class HandshakeTests(unittest.TestCase):
    def test_listener_exchanges_hello_ack_hello_on_the_wire(self) -> None:
        server = _start_listen("--port", "0", "--once")
        self.addCleanup(lambda: server.poll() is None and server.kill())
        assert server.stdout is not None
        listening = server.stdout.readline().strip()
        host, port_text = listening.removeprefix("listening on ").rsplit(":", 1)

        with socket.create_connection((host, int(port_text)), timeout=2) as connection:
            connection.sendall(HELLO)
            reply = _read_line(connection)

        stdout, stderr = server.communicate(timeout=5)
        self.assertEqual(reply, ACK_HELLO)
        self.assertEqual(server.returncode, 0, stderr)
        self.assertEqual(stdout, "hello\n")

    def test_cli_listen_defaults_to_female_rx_port(self) -> None:
        server = _start_listen("--once")
        self.addCleanup(lambda: server.poll() is None and server.kill())
        assert server.stdout is not None
        listening = server.stdout.readline().strip()
        self.assertEqual(listening, f"listening on {FEMALE_RX[0]}:{FEMALE_RX[1]}")

        with socket.create_connection(FEMALE_RX, timeout=2) as connection:
            connection.sendall(HELLO)
            reply = _read_line(connection)
            connection.setsockopt(
                socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0)
            )

        stdout, stderr = server.communicate(timeout=5)
        self.assertEqual(reply, ACK_HELLO)
        self.assertEqual(server.returncode, 0, stderr)
        self.assertEqual(stdout, "hello\n")

    def test_cli_hello_defaults_to_male_tx_port(self) -> None:
        received: dict[str, bytes] = {}
        ready = threading.Event()

        def serve() -> None:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
                listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                listener.bind(MALE_TX)
                listener.listen(1)
                listener.settimeout(5)
                ready.set()
                connection, _ = listener.accept()
                with connection:
                    connection.settimeout(2)
                    received["line"] = _read_line(connection)
                    connection.sendall(ACK_HELLO)

        worker = threading.Thread(target=serve)
        worker.start()
        self.addCleanup(worker.join)
        self.assertTrue(ready.wait(2), "male TX test listener did not bind")

        client = subprocess.run(
            _cli("hello"),
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        worker.join(timeout=5)
        self.assertEqual(client.returncode, 0, client.stderr)
        self.assertEqual(client.stdout, "ack-hello\n")
        self.assertEqual(received.get("line"), HELLO)

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

        rejected = subprocess.run(
            _cli("listen", "--host", "0.0.0.0", "--once"),
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn("loopback", rejected.stderr)

    def test_cli_completes_hello_ack_hello(self) -> None:
        server = _start_listen("--port", "0", "--once")
        self.addCleanup(lambda: server.poll() is None and server.kill())
        assert server.stdout is not None
        listening = server.stdout.readline().strip()
        port = listening.rsplit(":", 1)[1]

        client = subprocess.run(
            _cli("hello", "--port", port),
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
        server = _start_listen("--port", "0", "--once")
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

    def test_listener_continues_after_peer_resets_before_ack(self) -> None:
        server = _start_listen("--port", "0", "--once")
        self.addCleanup(lambda: server.poll() is None and server.kill())
        assert server.stdout is not None
        listening = server.stdout.readline().strip()
        host, port_text = listening.removeprefix("listening on ").rsplit(":", 1)
        port = int(port_text)

        with socket.create_connection((host, port), timeout=2) as connection:
            connection.sendall(HELLO)
            connection.setsockopt(
                socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0)
            )
        time.sleep(0.1)

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

            worker = threading.Thread(target=reply)
            worker.start()
            self.addCleanup(worker.join)
            with self.assertRaises(HandshakeError):
                send_hello("127.0.0.1", port, timeout=2)


if __name__ == "__main__":
    unittest.main()
