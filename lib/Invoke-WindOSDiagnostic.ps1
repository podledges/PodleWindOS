#Requires -Version 5.1
<#
.SYNOPSIS
    Run a WindOS-triggered read-only diagnostic on the Windows main OS.
.DESCRIPTION
    Allowlisted commands only: computer-info, disk, process-list, adapters,
    battery. No elevation, registry writes, process kills, or installs.
    This path is separate from the PORT-NIXVM/1 handshake.
.EXAMPLE
    .\Invoke-WindOSDiagnostic.ps1 computer-info
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('computer-info', 'disk', 'process-list', 'adapters', 'battery')]
    [string]$Command
)

$ErrorActionPreference = 'Stop'
Import-Module -Force (Join-Path $PSScriptRoot 'PodleWindOS.psm1')

try {
    $output = Invoke-ReadOnlyDiagnostic -Command $Command
    [Console]::Out.Write($output)
    [Console]::Out.Flush()
} catch {
    [Console]::Error.WriteLine("podlewindos: $($_.Exception.Message)")
    exit 1
}
