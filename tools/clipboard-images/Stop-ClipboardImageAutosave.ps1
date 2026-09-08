[CmdletBinding()]
param(
    [string]$StateDirectory = "$env:LOCALAPPDATA\PodleWindOS\ClipboardImageAutosave\state"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$helperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'ClipboardImageAutosave.ps1'))
$pidPath = Join-Path $StateDirectory 'listener.pid'
if (-not (Test-Path -LiteralPath $pidPath)) {
    Write-Output 'Clipboard image autosave is not running.'
    exit 0
}

$recordedPid = 0
if (-not [int]::TryParse((Get-Content -LiteralPath $pidPath -Raw).Trim(), [ref]$recordedPid)) {
    throw "Invalid PID file: $pidPath"
}

$process = Get-CimInstance Win32_Process -Filter "ProcessId = $recordedPid" -ErrorAction SilentlyContinue
if ($null -eq $process) {
    Remove-Item -LiteralPath $pidPath -Force
    Write-Output 'Clipboard image autosave was not running; removed its stale PID file.'
    exit 0
}
if ($null -eq $process.CommandLine -or
    $process.CommandLine.IndexOf($helperPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "PID $recordedPid does not belong to $helperPath; refusing to stop it."
}

Stop-Process -Id $recordedPid -ErrorAction Stop
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 100
    if ($null -eq (Get-Process -Id $recordedPid -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
        Write-Output "Clipboard image autosave stopped (PID $recordedPid)."
        exit 0
    }
}

throw "Clipboard image autosave process $recordedPid did not stop within 2 seconds."
