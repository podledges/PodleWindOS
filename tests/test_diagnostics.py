from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "bin" / "podlewindos"
sys.path.insert(0, str(ROOT / "src"))

from podlewindos.diagnostics import DiagnosticError, run_diagnostic

V1_COMMANDS = (
    "computer-info",
    "disk",
    "process-list",
    "adapters",
    "battery",
)


class DiagnosticTests(unittest.TestCase):
    def test_each_v1_diagnostic_dispatches_to_runner(self) -> None:
        seen: list[str] = []

        def runner(command: str) -> str:
            seen.append(command)
            return f"result-{command}\n"

        for name in V1_COMMANDS:
            with self.subTest(command=name):
                body = run_diagnostic(name, runner=runner)
                self.assertEqual(body, f"result-{name}\n")
        self.assertEqual(seen, list(V1_COMMANDS))

    def test_unknown_command_is_refused_without_running_anything(self) -> None:
        def runner(command: str) -> str:
            raise AssertionError(f"runner should not run for {command}")

        with self.assertRaises(DiagnosticError) as ctx:
            run_diagnostic("kill-process", runner=runner)
        self.assertIn("not allowed", str(ctx.exception))

    def test_privileged_looking_commands_are_refused(self) -> None:
        def runner(command: str) -> str:
            raise AssertionError(f"runner should not run for {command}")

        refused = (
            "Stop-Process",
            "Remove-Item",
            "Set-ItemProperty",
            "Install-Package",
            "Start-Process",
            "registry-write",
        )
        for command in refused:
            with self.subTest(command=command):
                with self.assertRaises(DiagnosticError):
                    run_diagnostic(command, runner=runner)

    def test_non_windows_default_runner_is_refused(self) -> None:
        if sys.platform.startswith("win"):
            self.skipTest("default runner is available on Windows")
        with self.assertRaises(DiagnosticError) as ctx:
            run_diagnostic("computer-info")
        self.assertIn("Windows", str(ctx.exception))

    def test_cli_diag_unknown_exits_nonzero(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(BIN), "diag", "Stop-Process"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(completed.stdout, "")

    def test_cli_diag_without_windows_runner_fails(self) -> None:
        if sys.platform.startswith("win"):
            self.skipTest("default runner is available on Windows")
        completed = subprocess.run(
            [sys.executable, str(BIN), "diag", "disk"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(completed.stdout, "")
        self.assertIn("Windows", completed.stderr)


if __name__ == "__main__":
    unittest.main()
