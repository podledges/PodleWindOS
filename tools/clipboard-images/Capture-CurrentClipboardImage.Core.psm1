Set-StrictMode -Version 2.0

function ConvertTo-CapturePngBytes {
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

function Get-CapturePngSha256 {
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

function ConvertTo-CaptureJsonString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        $code = [int]$char
        if ($code -eq 34) {
            [void]$builder.Append('\"')
        }
        elseif ($code -eq 92) {
            [void]$builder.Append('\\')
        }
        elseif ($code -eq 8) {
            [void]$builder.Append('\b')
        }
        elseif ($code -eq 12) {
            [void]$builder.Append('\f')
        }
        elseif ($code -eq 10) {
            [void]$builder.Append('\n')
        }
        elseif ($code -eq 13) {
            [void]$builder.Append('\r')
        }
        elseif ($code -eq 9) {
            [void]$builder.Append('\t')
        }
        elseif ($code -lt 32) {
            [void]$builder.Append(('\u{0:x4}' -f $code))
        }
        else {
            [void]$builder.Append($char)
        }
    }
    return $builder.ToString()
}

function Format-CaptureSuccessJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Sha256
    )

    if ($Sha256 -notmatch '^[0-9a-f]{64}$') {
        throw 'sha256 must be 64 lowercase hex characters'
    }

    $escapedPath = ConvertTo-CaptureJsonString -Value $Path
    return ('{"schema":1,"kind":"image","label":"Screenshot Pasted","path":"' + $escapedPath + '","sha256":"' + $Sha256 + '"}')
}

function Publish-CapturePngAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$PngBytes,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory
    )

    $destination = [System.IO.Path]::GetFullPath($DestinationDirectory)
    [System.IO.Directory]::CreateDirectory($destination) | Out-Null

    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        $name = 'paste-{0}-{1}.png' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')), ([guid]::NewGuid().ToString('N'))
        $finalPath = [System.IO.Path]::Combine($destination, $name)
        $tempPath = $finalPath + '.tmp'
        try {
            $stream = New-Object System.IO.FileStream(
                $tempPath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
            try {
                $stream.Write($PngBytes, 0, $PngBytes.Length)
                $stream.Flush()
            }
            finally {
                $stream.Dispose()
            }
            [System.IO.File]::Move($tempPath, $finalPath)
            return $finalPath
        }
        catch [System.IO.IOException] {
            if ([System.IO.File]::Exists($tempPath)) {
                [System.IO.File]::Delete($tempPath)
            }
            if ($attempt -eq 7) {
                throw
            }
        }
    }

    throw 'Could not publish a unique paste PNG.'
}

function Invoke-CurrentClipboardImageCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory,

        [Parameter(Mandatory = $true)]
        [scriptblock]$GetSequence,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ContainsImage,

        [Parameter(Mandatory = $true)]
        [scriptblock]$GetImage,

        [int]$RetryCount = 5
    )

    if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
        throw 'DestinationDirectory is required.'
    }

    $lastError = $null
    for ($attempt = 0; $attempt -lt $RetryCount; $attempt++) {
        $image = $null
        try {
            $sequenceBefore = & $GetSequence
            if (-not [bool](& $ContainsImage)) {
                throw 'clipboard is not an image'
            }

            $image = & $GetImage
            $sequenceAfter = & $GetSequence
            if ($sequenceBefore -ne $sequenceAfter) {
                throw 'clipboard changed during capture'
            }
            if ($null -eq $image) {
                throw 'clipboard advertised an image but returned no image data'
            }

            $pngBytes = ConvertTo-CapturePngBytes -Image $image
            $sha256 = Get-CapturePngSha256 -PngBytes $pngBytes
            $path = Publish-CapturePngAtomic -PngBytes $pngBytes -DestinationDirectory $DestinationDirectory
            return [pscustomobject]@{
                Path   = $path
                Sha256 = $sha256
            }
        }
        catch {
            $message = $_.Exception.Message
            if ($message -eq 'clipboard is not an image' -or $message -eq 'clipboard changed during capture') {
                throw
            }
            $lastError = $_
            if ($attempt -eq ($RetryCount - 1)) {
                throw
            }
            Start-Sleep -Milliseconds (40 * ($attempt + 1))
        }
        finally {
            if ($null -ne $image) {
                $image.Dispose()
            }
        }
    }

    if ($null -ne $lastError) {
        throw $lastError
    }
    throw 'clipboard image capture failed'
}

Export-ModuleMember -Function ConvertTo-CapturePngBytes, Get-CapturePngSha256, Format-CaptureSuccessJson, Publish-CapturePngAtomic, Invoke-CurrentClipboardImageCapture
