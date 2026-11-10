# Run from any directory: powershell -File flutter_app/scripts/generate_branding.ps1
# Draws the app's existing arrowword emblem and exports all launcher icon sizes.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$appRoot = Split-Path -Parent $PSScriptRoot
$canvasSize = 1024
$bitmap = [System.Drawing.Bitmap]::new($canvasSize, $canvasSize)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function New-RoundedPath([single]$x, [single]$y, [single]$size, [single]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc(($x + $size - $diameter), $y, $diameter, $diameter, 270, 90)
    $path.AddArc(($x + $size - $diameter), ($y + $size - $diameter), $diameter, $diameter, 0, 90)
    $path.AddArc($x, ($y + $size - $diameter), $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return ,$path
}

$primary = [System.Drawing.ColorTranslator]::FromHtml('#315C52')
$background = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    [System.Drawing.Point]::new(1024, 0), [System.Drawing.Point]::new(0, 1024),
    [System.Drawing.ColorTranslator]::FromHtml('#294F46'),
    [System.Drawing.ColorTranslator]::FromHtml('#3C685B'))
$graphics.FillRectangle($background, 0, 0, $canvasSize, $canvasSize)
$cream = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#F8F6F1'))
$gold = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#C6A66C'))
$sage = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#A8BFA3'))
$ink = [System.Drawing.SolidBrush]::new($primary)
$font = [System.Drawing.Font]::new('Tahoma', 112, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$format = [System.Drawing.StringFormat]::new()
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$arrow = [System.Drawing.Pen]::new($primary, 16)
$arrow.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$arrow.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$arrow.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
# The same Arabic letters used by PuzzleEmblem, expressed as Unicode codepoints.
$letters = @(0x0631, 0x0645, 0, 0x0634, 0x0633, 0x0645, 0, 0x0646, 0x0648)
for ($i = 0; $i -lt 9; $i++) {
    [single]$tileX = 176 + ($i % 3) * 232
    [single]$tileY = 176 + [Math]::Floor($i / 3) * 232
    $path = New-RoundedPath $tileX $tileY 208 34
    $fill = if ($i -eq 2 -or $i -eq 6) { $gold } elseif ($i -eq 4) { $sage } else { $cream }
    $graphics.FillPath($fill, $path)
    $path.Dispose()
    [single]$centerX = $tileX + 104
    [single]$centerY = $tileY + 104
    if ($i -eq 2) {
        $graphics.DrawLine($arrow, ($centerX + 48), $centerY, ($centerX - 48), $centerY)
        $graphics.DrawLine($arrow, ($centerX - 48), $centerY, ($centerX - 12), ($centerY - 36))
        $graphics.DrawLine($arrow, ($centerX - 48), $centerY, ($centerX - 12), ($centerY + 36))
    } elseif ($i -eq 6) {
        $graphics.DrawLine($arrow, $centerX, ($centerY - 48), $centerX, ($centerY + 48))
        $graphics.DrawLine($arrow, $centerX, ($centerY + 48), ($centerX - 36), ($centerY + 12))
        $graphics.DrawLine($arrow, $centerX, ($centerY + 48), ($centerX + 36), ($centerY + 12))
    } else {
        $rect = [System.Drawing.RectangleF]::new($tileX, ($tileY - 6), 208, 208)
        $graphics.DrawString([string][char]$letters[$i], $font, $ink, $rect, $format)
    }
}

function Save-Icon([string]$relativePath, [int]$size) {
    $target = Join-Path $appRoot $relativePath
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
    $scaled = [System.Drawing.Bitmap]::new($size, $size)
    $drawing = [System.Drawing.Graphics]::FromImage($scaled)
    $drawing.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $drawing.DrawImage($bitmap, 0, 0, $size, $size)
    $scaled.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $drawing.Dispose()
    $scaled.Dispose()
}

Save-Icon 'assets/branding/logo.png' 1024
Save-Icon 'web/favicon.png' 32
Save-Icon 'web/icons/Icon-192.png' 192
Save-Icon 'web/icons/Icon-512.png' 512
# Existing web projects can contain these icon files even without a manifest.
Save-Icon 'web/icons/Icon-maskable-192.png' 192
Save-Icon 'web/icons/Icon-maskable-512.png' 512
$densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
foreach ($density in $densities.GetEnumerator()) {
    Save-Icon "android/app/src/main/res/mipmap-$($density.Key)/ic_launcher.png" $density.Value
}
foreach ($platform in @('ios', 'macos')) {
    $catalog = "$platform/Runner/Assets.xcassets/AppIcon.appiconset"
    $manifest = Get-Content (Join-Path $appRoot "$catalog/Contents.json") -Raw | ConvertFrom-Json
    foreach ($entry in $manifest.images) {
        if (!$entry.filename) { continue }
        $points = [double]::Parse($entry.size.Split('x')[0], [Globalization.CultureInfo]::InvariantCulture)
        $scale = [int]$entry.scale.Replace('x', '')
        Save-Icon "$catalog/$($entry.filename)" ([int]($points * $scale))
    }
}

# Modern ICO containers support PNG frames, so no external conversion is needed.
$frames = @()
foreach ($size in @(32, 48, 64, 128, 256)) {
    $scaled = [System.Drawing.Bitmap]::new($size, $size)
    $drawing = [System.Drawing.Graphics]::FromImage($scaled)
    $drawing.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $drawing.DrawImage($bitmap, 0, 0, $size, $size)
    $stream = [System.IO.MemoryStream]::new()
    $scaled.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames += @{ Size = $size; Bytes = $stream.ToArray() }
    $stream.Dispose()
    $drawing.Dispose()
    $scaled.Dispose()
}
$iconFile = Join-Path $appRoot 'windows/runner/resources/app_icon.ico'
$writer = [System.IO.BinaryWriter]::new([System.IO.File]::Create($iconFile))
$writer.Write([uint16]0)
$writer.Write([uint16]1)
$writer.Write([uint16]$frames.Count)
[uint32]$offset = 6 + 16 * $frames.Count
foreach ($frame in $frames) {
    $dimension = if ($frame.Size -eq 256) { 0 } else { $frame.Size }
    $writer.Write([byte]$dimension)
    $writer.Write([byte]$dimension)
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]$frame.Bytes.Length)
    $writer.Write($offset)
    $offset += $frame.Bytes.Length
}
foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
$writer.Dispose()
foreach ($resource in @($graphics, $bitmap, $background, $cream, $gold, $sage, $ink, $font, $format, $arrow)) {
    $resource.Dispose()
}
Write-Output 'Generated splash logo and web, Android, iOS, macOS and Windows icons.'
