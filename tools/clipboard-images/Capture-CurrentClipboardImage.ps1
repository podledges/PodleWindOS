[CmdletBinding()]
param(
    [string]$DestinationDirectory = $(Join-Path $env:LOCALAPPDATA 'PodlePaste\staging')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-CaptureFailure {
    param([Parameter(Mandatory = $true)][string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 1
}

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
    Write-CaptureFailure 'Capture-CurrentClipboardImage.ps1 must run in STA. Call: powershell.exe -NoProfile -STA -File <script> [-DestinationDirectory <dir>]'
}

if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
    Write-CaptureFailure 'DestinationDirectory is required.'
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
}
catch {
    Write-CaptureFailure 'Failed to load System.Windows.Forms / System.Drawing for clipboard image capture.'
}

$sequenceType = @'
using System.Runtime.InteropServices;
public static class PodlePasteClipboardSequence {
    [DllImport("user32.dll")]
    public static extern uint GetClipboardSequenceNumber();
}
'@
if (-not ('PodlePasteClipboardSequence' -as [type])) {
    Add-Type -TypeDefinition $sequenceType
}

Import-Module -Name (Join-Path $PSScriptRoot 'Capture-CurrentClipboardImage.Core.psm1') -Force
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = [Console]::OutputEncoding

try {
    $result = Invoke-CurrentClipboardImageCapture `
        -DestinationDirectory $DestinationDirectory `
        -GetSequence { [PodlePasteClipboardSequence]::GetClipboardSequenceNumber() } `
        -ContainsImage { [System.Windows.Forms.Clipboard]::ContainsImage() } `
        -GetImage { [System.Windows.Forms.Clipboard]::GetImage() }
    Write-Output (Format-CaptureSuccessJson -Path $result.Path -Sha256 $result.Sha256)
    exit 0
}
catch {
    Write-CaptureFailure $_.Exception.Message
}
