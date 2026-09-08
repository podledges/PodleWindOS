Set-StrictMode -Version 2.0

function ConvertTo-ClipboardPngBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Image]$Image
    )

    $stream = New-Object System.IO.MemoryStream
    try {
        $Image.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        return [byte[]]$stream.ToArray()
    }
    finally {
        $stream.Dispose()
    }
}

function Get-ClipboardImageHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$PngBytes
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($PngBytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Write-CollisionSafeClipboardPng {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$PngBytes,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $false)]
        [DateTime]$Timestamp = [DateTime]::Now
    )

    [System.IO.Directory]::CreateDirectory($DestinationPath) | Out-Null
    $stem = 'clipboard-{0}' -f $Timestamp.ToString('yyyyMMdd-HHmmss-fff')

    for ($suffix = 0; $suffix -lt 10000; $suffix++) {
        $fileName = if ($suffix -eq 0) {
            '{0}.png' -f $stem
        }
        else {
            '{0}-{1:D3}.png' -f $stem, $suffix
        }
        $path = [System.IO.Path]::Combine($DestinationPath, $fileName)

        try {
            $stream = New-Object System.IO.FileStream(
                $path,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::Read
            )
            try {
                $stream.Write($PngBytes, 0, $PngBytes.Length)
                $stream.Flush()
            }
            finally {
                $stream.Dispose()
            }
            return $path
        }
        catch [System.IO.IOException] {
            if (-not [System.IO.File]::Exists($path)) {
                throw
            }
        }
    }

    throw 'Could not allocate a collision-free PNG filename after 10,000 attempts.'
}

function Save-NewClipboardImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$PngBytes,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [AllowNull()]
        [string]$PreviousHash,

        [Parameter(Mandatory = $false)]
        [DateTime]$Timestamp = [DateTime]::Now
    )

    $hash = Get-ClipboardImageHash -PngBytes $PngBytes
    if ($hash -eq $PreviousHash) {
        return [PSCustomObject]@{
            Saved = $false
            Hash = $hash
            Path = $null
        }
    }

    $path = Write-CollisionSafeClipboardPng -PngBytes $PngBytes -DestinationPath $DestinationPath -Timestamp $Timestamp
    return [PSCustomObject]@{
        Saved = $true
        Hash = $hash
        Path = $path
    }
}

Export-ModuleMember -Function ConvertTo-ClipboardPngBytes, Get-ClipboardImageHash, Write-CollisionSafeClipboardPng, Save-NewClipboardImage
