Set-StrictMode -Version Latest

function New-CentralMultiSizeIcon {
    param(
        [Parameter(Mandatory = $true)][string]$Base64AssetPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $Base64AssetPath -PathType Leaf)) {
        throw "Central icon asset not found: $Base64AssetPath"
    }

    $encodedIcon = (Get-Content -LiteralPath $Base64AssetPath -Raw).Trim()
    try { $imageBytes = [Convert]::FromBase64String($encodedIcon) }
    catch { throw "Central icon image asset is not valid Base64." }
    if ($imageBytes.Length -lt 1024) { throw "Central icon image asset is unexpectedly small." }

    Add-Type -AssemblyName System.Drawing
    $sourceStream = [IO.MemoryStream]::new($imageBytes)
    $sourceBitmap = $null
    $frames = [Collections.Generic.List[object]]::new()
    try {
        $sourceBitmap = [Drawing.Bitmap]::FromStream($sourceStream)
        if ($sourceBitmap.Width -ne 64 -or $sourceBitmap.Height -ne 64) {
            throw "Central icon image must be 64x64 pixels."
        }

        $sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
        foreach ($size in $sizes) {
            $bitmap = [Drawing.Bitmap]::new($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $pngStream = [IO.MemoryStream]::new()
            try {
                $graphics.Clear([Drawing.Color]::Transparent)
                $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver
                $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($sourceBitmap, [Drawing.Rectangle]::new(0, 0, $size, $size))
                $bitmap.Save($pngStream, [Drawing.Imaging.ImageFormat]::Png)
                $frames.Add([pscustomobject]@{ Size = $size; Bytes = $pngStream.ToArray() })
            }
            finally {
                $pngStream.Dispose()
                $graphics.Dispose()
                $bitmap.Dispose()
            }
        }
    }
    finally {
        if ($null -ne $sourceBitmap) { $sourceBitmap.Dispose() }
        $sourceStream.Dispose()
    }

    $directory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath))
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [void][IO.Directory]::CreateDirectory($directory)
    }

    $fileStream = [IO.File]::Create($OutputPath)
    $writer = [IO.BinaryWriter]::new($fileStream)
    try {
        $writer.Write([UInt16]0) # reserved
        $writer.Write([UInt16]1) # icon
        $writer.Write([UInt16]$frames.Count)

        $offset = 6 + (16 * $frames.Count)
        foreach ($frame in $frames) {
            $dimension = if ($frame.Size -ge 256) { [byte]0 } else { [byte]$frame.Size }
            $writer.Write($dimension)
            $writer.Write($dimension)
            $writer.Write([byte]0) # color count
            $writer.Write([byte]0) # reserved
            $writer.Write([UInt16]1) # planes
            $writer.Write([UInt16]32) # bit depth
            $writer.Write([UInt32]$frame.Bytes.Length)
            $writer.Write([UInt32]$offset)
            $offset += $frame.Bytes.Length
        }

        foreach ($frame in $frames) {
            $writer.Write([byte[]]$frame.Bytes)
        }
    }
    finally {
        $writer.Dispose()
        $fileStream.Dispose()
    }

    $icoBytes = [IO.File]::ReadAllBytes($OutputPath)
    if ($icoBytes.Length -lt 2048) { throw "Central multi-size ICO is unexpectedly small." }
    if ([BitConverter]::ToUInt16($icoBytes, 0) -ne 0 -or [BitConverter]::ToUInt16($icoBytes, 2) -ne 1) {
        throw "Central multi-size ICO has an invalid header."
    }
    $count = [BitConverter]::ToUInt16($icoBytes, 4)
    if ($count -ne 9) { throw "Central multi-size ICO contains $count frames instead of 9." }

    Write-Host "MULTI-SIZE ICON: OK - 16, 20, 24, 32, 40, 48, 64, 128 and 256 px."
}
