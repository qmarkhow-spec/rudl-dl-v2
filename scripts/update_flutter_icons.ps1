param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$SourceIcon,
  [double]$Scale = 1.0,
  [string]$BgColor = ""
)

Add-Type -AssemblyName System.Drawing

function Get-Color([string]$hex) {
  if ([string]::IsNullOrWhiteSpace($hex)) { return $null }
  $clean = $hex.TrimStart('#')
  if ($clean.Length -eq 6) {
    $r = [Convert]::ToInt32($clean.Substring(0,2),16)
    $g = [Convert]::ToInt32($clean.Substring(2,2),16)
    $b = [Convert]::ToInt32($clean.Substring(4,2),16)
    return [System.Drawing.Color]::FromArgb(255,$r,$g,$b)
  }
  return $null
}

function New-IconPng([string]$dest,[int]$size,[string]$src,[double]$scale,$bg) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  if ($bg -is [System.Drawing.Color]) {
    $g.Clear($bg)
  } else {
    $g.Clear([System.Drawing.Color]::Transparent)
  }
  $icon = [System.Drawing.Image]::FromFile($src)
  $target = [int]([Math]::Round($size * $scale))
  $x = [int](($size - $target) / 2)
  $y = [int](($size - $target) / 2)
  $g.DrawImage($icon, $x, $y, $target, $target)
  $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $icon.Dispose()
}

if (-not (Test-Path $ProjectRoot)) { throw "ProjectRoot not found" }
if (-not (Test-Path $SourceIcon)) { throw "SourceIcon not found" }

$bg = Get-Color $BgColor

# Android mipmaps
$mipmapRoot = Join-Path $ProjectRoot "android\\app\\src\\main\\res"
Get-ChildItem -Path $mipmapRoot -Directory | Where-Object { $_.Name -like 'mipmap-*' } | ForEach-Object {
  foreach ($name in @('ic_launcher.png','ic_launcher_round.png')) {
    $dest = Join-Path $_.FullName $name
    if (Test-Path $dest) {
      $img = [System.Drawing.Image]::FromFile($dest)
      $size = $img.Width
      $img.Dispose()
      New-IconPng $dest $size $SourceIcon $Scale $bg
    }
  }
}

# iOS AppIcon
$iosDir = Join-Path $ProjectRoot "ios\\Runner\\Assets.xcassets\\AppIcon.appiconset"
if (Test-Path $iosDir) {
  Get-ChildItem -Path $iosDir -Filter *.png | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $size = $img.Width
    $img.Dispose()
    New-IconPng $_.FullName $size $SourceIcon $Scale $bg
  }
}

# macOS AppIcon
$macDir = Join-Path $ProjectRoot "macos\\Runner\\Assets.xcassets\\AppIcon.appiconset"
if (Test-Path $macDir) {
  Get-ChildItem -Path $macDir -Filter *.png | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $size = $img.Width
    $img.Dispose()
    New-IconPng $_.FullName $size $SourceIcon $Scale $bg
  }
}

# Web icons + favicon
$webIconDir = Join-Path $ProjectRoot "web\\icons"
if (Test-Path $webIconDir) {
  Get-ChildItem -Path $webIconDir -Filter *.png | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $size = $img.Width
    $img.Dispose()
    New-IconPng $_.FullName $size $SourceIcon $Scale $bg
  }
}
$webFavicon = Join-Path $ProjectRoot "web\\favicon.png"
if (Test-Path $webFavicon) {
  $img = [System.Drawing.Image]::FromFile($webFavicon)
  $size = $img.Width
  $img.Dispose()
  New-IconPng $webFavicon $size $SourceIcon $Scale $bg
}

# Windows icon (single 256)
$icoPath = Join-Path $ProjectRoot "windows\\runner\\resources\\app_icon.ico"
if (Test-Path $icoPath) {
  $bmp = New-Object System.Drawing.Bitmap(256,256,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g2 = [System.Drawing.Graphics]::FromImage($bmp)
  $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  if ($bg -is [System.Drawing.Color]) { $g2.Clear($bg) } else { $g2.Clear([System.Drawing.Color]::Transparent) }
  $iconImg = [System.Drawing.Image]::FromFile($SourceIcon)
  $target = [int]([Math]::Round(256 * $Scale))
  $x = [int]((256 - $target)/2); $y = [int]((256 - $target)/2)
  $g2.DrawImage($iconImg, $x, $y, $target, $target)
  $hIcon = $bmp.GetHicon()
  $icon = [System.Drawing.Icon]::FromHandle($hIcon)
  $fs = [System.IO.File]::Open($icoPath,[System.IO.FileMode]::Create)
  $icon.Save($fs)
  $fs.Close()
  $icon.Dispose(); $iconImg.Dispose(); $g2.Dispose(); $bmp.Dispose()
}
