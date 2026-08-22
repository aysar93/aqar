Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot '..\assets\icon\icon_foreground.png'
$targetDirectory = Join-Path $PSScriptRoot '..\ios\Runner\Assets.xcassets\AppIcon.appiconset'
$sourceImage = [System.Drawing.Image]::FromFile($sourcePath)

try {
    Get-ChildItem -LiteralPath $targetDirectory -Filter '*.png' | ForEach-Object {
        $existingImage = [System.Drawing.Image]::FromFile($_.FullName)
        try {
            $width = $existingImage.Width
            $height = $existingImage.Height
        }
        finally {
            $existingImage.Dispose()
        }

        $bitmap = New-Object System.Drawing.Bitmap $width, $height,
            ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#0F172A'))
                $graphics.DrawImage($sourceImage, 0, 0, $width, $height)
            }
            finally {
                $graphics.Dispose()
            }

            $bitmap.Save($_.FullName, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $bitmap.Dispose()
        }
    }
}
finally {
    $sourceImage.Dispose()
}
