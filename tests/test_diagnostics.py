from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from podlewindos.diagnostics import (
    ALLOWED_COMMANDS,
    POWERSHELL_COMMANDS,
    DiagnosticError,
    run_diagnostic,
)


class DiagnosticTests(unittest.TestCase):
    def test_allowlist_is_the_v1_read_only_set(self) -> None:
        self.assertEqual(
            ALLOWED_COMMANDS,
            (
                "computer-info",
                "disk",
                "process-list",
                "adapters",
                "battery",
            ),
        )
        self.assertEqual(set(ALLOWED_COMMANDS), set(POWERSHELL_COMMANDS))

    def test_allowlisted_command_uses_injected_runner(self) -> None:
        seen: list[str] = []

        def runner(command: str) -> str:
            seen.append(command)
            return f"result-{command}\n"

        body = run_diagnostic("disk", runner=runner)
        self.assertEqual(body, "result-disk\n")
        self.assertEqual(seen, ["disk"])

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
            [sys.executable, str(ROOT / "bin" / "podlewindos"), "diag", "Stop-Process"],
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
            [sys.executable, str(ROOT / "bin" / "podlewindos"), "diag", "disk"],
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
