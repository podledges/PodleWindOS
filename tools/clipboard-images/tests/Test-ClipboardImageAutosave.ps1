[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Add-Type -AssemblyName System.Drawing
Import-Module (Join-Path $root 'ClipboardImageAutosave.Core.psm1') -Force
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('PodleWindOS-ClipboardImageAutosave-Test-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($temp) | Out-Null

try {
    $bitmapA = New-Object System.Drawing.Bitmap(3, 2)
    $bitmapB = New-Object System.Drawing.Bitmap(3, 2)
    try {
        $bitmapA.SetPixel(0, 0, [System.Drawing.Color]::Red)
        $bitmapA.SetPixel(2, 1, [System.Drawing.Color]::Blue)
        $bitmapB.SetPixel(0, 0, [System.Drawing.Color]::Green)
        $bitmapB.SetPixel(2, 1, [System.Drawing.Color]::Blue)
        $pngA = ConvertTo-ClipboardPngBytes -Image $bitmapA
        $pngB = ConvertTo-ClipboardPngBytes -Image $bitmapB
    }
    finally {
        $bitmapA.Dispose()
        $bitmapB.Dispose()
    }

    Assert-True ($pngA.Length -gt 8) 'synthetic image should encode to PNG bytes'
    Assert-True ($pngA[0] -eq 137 -and $pngA[1] -eq 80 -and $pngA[2] -eq 78 -and $pngA[3] -eq 71) 'encoded file should have a PNG signature'
    Assert-True ((Get-ClipboardImageHash -PngBytes $pngA) -ne (Get-ClipboardImageHash -PngBytes $pngB)) 'different images should have different hashes'

    $timestamp = [DateTime]::new(2025, 8, 24, 12, 34, 56, 789)
    $first = Save-NewClipboardImage -PngBytes $pngA -DestinationPath $temp -PreviousHash $null -Timestamp $timestamp
    Assert-True $first.Saved 'first image should be saved'
    Assert-True ([System.IO.Path]::GetFileName($first.Path) -eq 'clipboard-20250824-123456-789.png') 'filename should use the expected timestamp'
    $firstBytes = [System.IO.File]::ReadAllBytes($first.Path)

    $duplicate = Save-NewClipboardImage -PngBytes $pngA -DestinationPath $temp -PreviousHash $first.Hash -Timestamp $timestamp
    Assert-True (-not $duplicate.Saved) 'consecutive identical image data should be deduplicated'
    Assert-True (@(Get-ChildItem -LiteralPath $temp -Filter '*.png').Count -eq 1) 'deduplication should not create a file'

    $collision = Save-NewClipboardImage -PngBytes $pngB -DestinationPath $temp -PreviousHash $first.Hash -Timestamp $timestamp
    Assert-True $collision.Saved 'different image data should be saved'
    Assert-True ([System.IO.Path]::GetFileName($collision.Path) -eq 'clipboard-20250824-123456-789-001.png') 'a timestamp collision should receive a numeric suffix'
    $firstBytesAfterCollision = [System.IO.File]::ReadAllBytes($first.Path)
    Assert-True ([Convert]::ToBase64String($firstBytes) -eq [Convert]::ToBase64String($firstBytesAfterCollision)) 'collision handling must not overwrite the first image'

    $tokens = $null
    $parseErrors = $null
    Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse | ForEach-Object {
        [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
        $parseMessage = if (@($parseErrors).Count -eq 0) { 'no parse errors' } else { @($parseErrors | ForEach-Object { $_.Message }) -join '; ' }
        Assert-True (@($parseErrors).Count -eq 0) ("PowerShell syntax should be valid in {0}: {1}" -f $_.Name, $parseMessage)
    }

    $listenerSource = [System.IO.File]::ReadAllText((Join-Path $root 'ClipboardImageAutosave.ps1'))
    Assert-True ($listenerSource -match 'AddClipboardFormatListener') 'listener should use clipboard event notifications'
    Assert-True ($listenerSource -match '\[System\.Windows\.Forms\.Application\]::Run\(\)') 'listener should use a Windows message loop'
    Assert-True ($listenerSource -notmatch '(?i)Clipboard\]\s*::\s*(Set|Clear)|Set-(Clipboard|ClipboardText)') 'helper must never write or clear the clipboard'
    Assert-True ($listenerSource -match '\$script:lastSequence\s*=\s*\[PodleWindOSClipboardListener\]::GetClipboardSequenceNumber\(\)') 'listener should establish a startup sequence without reading old clipboard content'
    Assert-True ($listenerSource -match "Local\\PodleShell\.ClipboardImageAutosave") 'migration must retain the deployed mutex identity for cross-owner singleton safety'
    Assert-True ($listenerSource -notmatch '(?i)System\.Net|HttpClient|WebClient|Invoke-WebRequest|Invoke-RestMethod') 'listener must not add network or upload behavior'

    Write-Output 'PASS: synthetic PNG encoding, hash deduplication, collision-safe writes, syntax, clipboard read-only policy, and migration safety.'
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
