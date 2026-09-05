"""WindOS-triggered read-only diagnostics. Not part of the handshake."""

from __future__ import annotations

import os
import shutil
import subprocess
from collections.abc import Callable, Mapping

ALLOWED_COMMANDS = (
    "computer-info",
    "disk",
    "process-list",
    "adapters",
    "battery",
)

# Hardcoded cmdlets only. User input selects a key; it is never interpolated.
POWERSHELL_COMMANDS: Mapping[str, str] = {
    "computer-info": "Get-ComputerInfo | Out-String",
    "disk": (
        "Get-PSDrive -PSProvider FileSystem | "
        "Select-Object Name,Used,Free | Format-List | Out-String"
    ),
    "process-list": (
        "Get-Process | Select-Object Id,ProcessName,CPU,WorkingSet64 | "
        "Format-Table -AutoSize | Out-String"
    ),
    "adapters": (
        "Get-NetAdapter | Select-Object Name,Status,MacAddress,LinkSpeed | "
        "Format-List | Out-String"
    ),
    "battery": (
        "Get-CimInstance -ClassName Win32_Battery | "
        "Select-Object Name,EstimatedChargeRemaining,BatteryStatus | "
        "Format-List | Out-String"
    ),
}


class DiagnosticError(Exception):
    """A diagnostic request was refused or could not run."""


def _powershell_executable() -> str:
    for name in ("powershell.exe", "powershell", "pwsh"):
        found = shutil.which(name)
        if found:
            return found
    raise DiagnosticError("Windows PowerShell is not available")


def powershell_runner(command: str) -> str:
    script = POWERSHELL_COMMANDS[command]
    completed = subprocess.run(
        [
            _powershell_executable(),
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip() or "command failed"
        raise DiagnosticError(detail)
    return completed.stdout


def run_diagnostic(
    command: str,
    runner: Callable[[str], str] | None = None,
) -> str:
    if command not in POWERSHELL_COMMANDS:
        raise DiagnosticError(f"command not allowed: {command}")
    if runner is None:
        if os.name != "nt":
            raise DiagnosticError("Windows diagnostics require Windows PowerShell")
        runner = powershell_runner
    return runner(command)
