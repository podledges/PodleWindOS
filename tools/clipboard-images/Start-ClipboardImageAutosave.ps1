[CmdletBinding()]
param(
    [string]$DestinationPath = 'C:\Users\ayden\Pictures\Screenshots2',
    [string]$StateDirectory = "$env:LOCALAPPDATA\PodleWindOS\ClipboardImageAutosave\state"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$helperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'ClipboardImageAutosave.ps1'))
$pidPath = Join-Path $StateDirectory 'listener.pid'
[System.IO.Directory]::CreateDirectory($DestinationPath) | Out-Null
[System.IO.Directory]::CreateDirectory($StateDirectory) | Out-Null

if (Test-Path -LiteralPath $pidPath) {
    $recordedPid = 0
    if ([int]::TryParse((Get-Content -LiteralPath $pidPath -Raw).Trim(), [ref]$recordedPid)) {
        $existing = Get-CimInstance Win32_Process -Filter "ProcessId = $recordedPid" -ErrorAction SilentlyContinue
        if ($null -ne $existing -and $null -ne $existing.CommandLine -and
            $existing.CommandLine.IndexOf($helperPath, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Write-Output "Clipboard image autosave is already running (PID $recordedPid)."
            exit 0
        }
    }
    Remove-Item -LiteralPath $pidPath -Force
}

$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = @(
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-STA',
    '-ExecutionPolicy', 'Bypass',
    '-File', ('"{0}"' -f $helperPath),
    '-DestinationPath', ('"{0}"' -f $DestinationPath),
    '-StateDirectory', ('"{0}"' -f $StateDirectory)
)
$process = Start-Process -FilePath $powerShell -ArgumentList $arguments -WindowStyle Hidden -PassThru

for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 100
    if (Test-Path -LiteralPath $pidPath) {
        $listenerPid = (Get-Content -LiteralPath $pidPath -Raw).Trim()
        Write-Output "Clipboard image autosave started (PID $listenerPid)."
        exit 0
    }
    if ($process.HasExited) {
        throw "Clipboard image autosave exited during startup with code $($process.ExitCode). Check $StateDirectory\errors.log."
    }
}

throw "Clipboard image autosave did not report ready within 3 seconds. Check $StateDirectory\errors.log."
