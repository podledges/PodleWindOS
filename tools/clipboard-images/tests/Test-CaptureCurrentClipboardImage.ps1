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
Import-Module (Join-Path $root 'Capture-CurrentClipboardImage.Core.psm1') -Force
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('PodleWindOS-CaptureCurrentClipboardImage-Test-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($temp) | Out-Null

try {
    $bitmapA = New-Object System.Drawing.Bitmap(3, 2)
    $bitmapB = New-Object System.Drawing.Bitmap(4, 1)
    try {
        $bitmapA.SetPixel(0, 0, [System.Drawing.Color]::Red)
        $bitmapA.SetPixel(2, 1, [System.Drawing.Color]::Blue)
        $bitmapB.SetPixel(0, 0, [System.Drawing.Color]::Green)
        $pngA = ConvertTo-CapturePngBytes -Image $bitmapA
        $pngB = ConvertTo-CapturePngBytes -Image $bitmapB
    }
    finally {
        $bitmapA.Dispose()
        $bitmapB.Dispose()
    }

    Assert-True ($pngA.Length -gt 8) 'synthetic image should encode to PNG bytes'
    Assert-True ($pngA[0] -eq 137 -and $pngA[1] -eq 80 -and $pngA[2] -eq 78 -and $pngA[3] -eq 71) 'encoded file should have a PNG signature'
    Assert-True ((Get-CapturePngSha256 -PngBytes $pngA) -ne (Get-CapturePngSha256 -PngBytes $pngB)) 'different images should have different hashes'

    $published = Publish-CapturePngAtomic -PngBytes $pngA -DestinationDirectory $temp
    Assert-True ([System.IO.File]::Exists($published)) 'atomic publish should create the destination PNG'
    Assert-True ([System.IO.Path]::GetFileName($published) -match '^paste-\d{8}T\d{9}Z-[0-9a-f]{32}\.png$') 'paste PNG names must be unique and immutable'
    $firstBytes = [System.IO.File]::ReadAllBytes($published)
    Assert-True ([Convert]::ToBase64String($firstBytes) -eq [Convert]::ToBase64String($pngA)) 'published bytes must match encoded PNG'

    $publishedB = Publish-CapturePngAtomic -PngBytes $pngB -DestinationDirectory $temp
    Assert-True ($publishedB -ne $published) 'a second paste must not reuse the first path'
    $firstBytesAfter = [System.IO.File]::ReadAllBytes($published)
    Assert-True ([Convert]::ToBase64String($firstBytes) -eq [Convert]::ToBase64String($firstBytesAfter)) 'a later paste must not change an earlier PNG'

    $json = Format-CaptureSuccessJson -Path $published -Sha256 (Get-CapturePngSha256 -PngBytes $pngA)
    Assert-True ($json -match '"schema":\s*1') 'success JSON must include schema 1'
    Assert-True ($json -match '"kind":\s*"image"') 'success JSON kind must be image'
    Assert-True ($json -match '"label":\s*"Screenshot Pasted"') 'success JSON label must be Screenshot Pasted'
    Assert-True ($json.Contains($published.Replace('\', '\\')) -or $json.Contains($published)) 'success JSON must include the absolute path'
    Assert-True ($json -match ('"sha256":\s*"' + (Get-CapturePngSha256 -PngBytes $pngA) + '"')) 'success JSON sha256 must match PNG bytes'

    $seq = @{ Value = 10 }
    $captured = Invoke-CurrentClipboardImageCapture `
        -DestinationDirectory $temp `
        -GetSequence { $seq.Value }.GetNewClosure() `
        -ContainsImage { $true } `
        -GetImage {
            $bitmap = New-Object System.Drawing.Bitmap(2, 2)
            $bitmap.SetPixel(0, 0, [System.Drawing.Color]::Navy)
            return $bitmap
        }
    Assert-True ([System.IO.File]::Exists($captured.Path)) 'mock capture should publish a PNG'
    Assert-True ($captured.Sha256.Length -eq 64) 'sha256 must be 64 lowercase hex characters'

    $beforeRaceCount = @(Get-ChildItem -LiteralPath $temp -Filter 'paste-*.png').Count
    $raced = $false
    try {
        $raceSeq = @{ Value = 1 }
        Invoke-CurrentClipboardImageCapture `
            -DestinationDirectory $temp `
            -GetSequence { $raceSeq.Value++; $raceSeq.Value }.GetNewClosure() `
            -ContainsImage { $true } `
            -GetImage { New-Object System.Drawing.Bitmap(1, 1) } | Out-Null
    }
    catch {
        $raced = $_.Exception.Message -eq 'clipboard changed during capture'
    }
    Assert-True $raced 'sequence mismatch must fail the capture'
    $afterRaceCount = @(Get-ChildItem -LiteralPath $temp -Filter 'paste-*.png').Count
    Assert-True ($afterRaceCount -eq $beforeRaceCount) 'a raced capture must not leave a success PNG'

    $notImage = $false
    try {
        Invoke-CurrentClipboardImageCapture `
            -DestinationDirectory $temp `
            -GetSequence { 1 } `
            -ContainsImage { $false } `
            -GetImage { throw 'GetImage must not run when clipboard is not an image' } | Out-Null
    }
    catch {
        $notImage = $_.Exception.Message -eq 'clipboard is not an image'
    }
    Assert-True $notImage 'non-image clipboard must fail without calling GetImage'

    $nullImage = $false
    try {
        Invoke-CurrentClipboardImageCapture `
            -DestinationDirectory $temp `
            -RetryCount 1 `
            -GetSequence { 3 } `
            -ContainsImage { $true } `
            -GetImage { $null } | Out-Null
    }
    catch {
        $nullImage = $_.Exception.Message -eq 'clipboard advertised an image but returned no image data'
    }
    Assert-True $nullImage 'null GetImage must fail'

    $tokens = $null
    $parseErrors = $null
    Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse | ForEach-Object {
        [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
        $parseMessage = if (@($parseErrors).Count -eq 0) { 'no parse errors' } else { @($parseErrors | ForEach-Object { $_.Message }) -join '; ' }
        Assert-True (@($parseErrors).Count -eq 0) ("PowerShell syntax should be valid in {0}: {1}" -f $_.Name, $parseMessage)
    }

    $entrySource = [System.IO.File]::ReadAllText((Join-Path $root 'Capture-CurrentClipboardImage.ps1'))
    $coreSource = [System.IO.File]::ReadAllText((Join-Path $root 'Capture-CurrentClipboardImage.Core.psm1'))
    $production = $entrySource + "`n" + $coreSource
    Assert-True ($entrySource -match '\[Threading\.ApartmentState\]::STA') 'entry script must require STA'
    Assert-True ($entrySource -match 'DestinationDirectory') 'entry script must accept -DestinationDirectory'
    Assert-True ($entrySource -match 'PodlePaste\\staging') 'default staging dir must be LOCALAPPDATA/PodlePaste/staging'
    Assert-True ($coreSource -match 'GetSequence' -and $coreSource -match 'sequenceBefore' -and $coreSource -match 'sequenceAfter') 'capture must sequence-check before and after the image read'
    Assert-True ($production -notmatch '(?i)Clipboard\]\s*::\s*(Set|Clear)|Set-(Clipboard|ClipboardText)') 'capture must never write or clear the clipboard'
    Assert-True ($production -notmatch '(?i)Screenshots2') 'capture must not reference Screenshots2'
    Assert-True ($coreSource -notmatch '(?i)Get-ChildItem') 'production capture must not enumerate folders'
    Assert-True ($production -notmatch '(?i)System\.Net|HttpClient|WebClient|Invoke-WebRequest|Invoke-RestMethod') 'capture must not add network or upload behavior'

    Write-Output 'PASS: synthetic PNG encoding, unique immutable publish, JSON contract, sequence race, non-image refusal, syntax, and clipboard read-only policy.'
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
