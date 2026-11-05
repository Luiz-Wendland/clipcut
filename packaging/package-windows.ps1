$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Build = Join-Path $Root "deployment\ClipCut.dist"
$Exe = Join-Path $Build "main.exe"
$Out = Join-Path $Root "dist"
$Stage = Join-Path $env:TEMP ("ClipCut-package-" + [guid]::NewGuid().ToString("N"))
$Archive = Join-Path $Out "ClipCut-windows-x86_64.zip"
$Installer = Join-Path $Out "ClipCut-windows-x86_64.msi"
$Wxs = Join-Path $PSScriptRoot "clipcut-product.wxs"
$WixWork = Join-Path $env:TEMP ("ClipCut-wix-" + [guid]::NewGuid().ToString("N"))
$Harvest = Join-Path $WixWork "harvest.wxs"

if (!(Test-Path $Exe)) {
    throw "Standalone build not found: $Exe"
}

New-Item -ItemType Directory -Path $Out -Force | Out-Null
New-Item -ItemType Directory -Path $Stage -Force | Out-Null
New-Item -ItemType Directory -Path $WixWork -Force | Out-Null
try {
    Copy-Item (Join-Path $Build "*") $Stage -Recurse -Force
    Copy-Item (Join-Path $Root "README.md") (Join-Path $Stage "README.md")
    Copy-Item (Join-Path $Root "LICENSE") (Join-Path $Stage "LICENSE")
    Copy-Item (Join-Path $PSScriptRoot "README-BINARY.txt") (Join-Path $Stage "README-BINARY.txt")
    Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $Archive -Force

    $Heat = (Get-Command heat.exe -ErrorAction Stop).Source
    $Candle = (Get-Command candle.exe -ErrorAction Stop).Source
    $Light = (Get-Command light.exe -ErrorAction Stop).Source
    & $Heat dir $Stage -arch x64 -cg ClipCutFiles -dr INSTALLFOLDER -var var.SourceDir -gg -sfrag -srd -out $Harvest
    if ($LASTEXITCODE -ne 0) { throw "WiX heat failed with exit code $LASTEXITCODE" }
    [xml]$HarvestDocument = Get-Content -Path $Harvest -Raw
    foreach ($Component in $HarvestDocument.SelectNodes("//*[local-name()='Component']")) {
        $Component.SetAttribute("Win64", "yes")
    }
    $HarvestDocument.Save($Harvest)
    & $Candle -nologo "-dSourceDir=$Stage" -out (Join-Path $WixWork "") $Wxs $Harvest
    if ($LASTEXITCODE -ne 0) { throw "WiX candle failed with exit code $LASTEXITCODE" }
    & $Light -nologo -ext WixUIExtension -out $Installer (Join-Path $WixWork "clipcut-product.wixobj") (Join-Path $WixWork "harvest.wixobj")
    if ($LASTEXITCODE -ne 0) { throw "WiX light failed with exit code $LASTEXITCODE" }
} finally {
    Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $WixWork -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "Created $Archive"
Write-Output "Created $Installer"
