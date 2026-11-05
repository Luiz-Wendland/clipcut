$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Build = Join-Path $Root "deployment\ClipCut.dist"
$Exe = Join-Path $Build "main.exe"
$Out = Join-Path $Root "dist"
$Stage = Join-Path $env:TEMP ("ClipCut-package-" + [guid]::NewGuid().ToString("N"))
$Archive = Join-Path $Out "ClipCut-windows-x86_64.zip"

if (!(Test-Path $Exe)) {
    throw "Standalone build not found: $Exe"
}

New-Item -ItemType Directory -Path $Out -Force | Out-Null
New-Item -ItemType Directory -Path $Stage -Force | Out-Null
try {
    Copy-Item (Join-Path $Build "*") $Stage -Recurse -Force
    Copy-Item (Join-Path $Root "README.md") (Join-Path $Stage "README.md")
    Copy-Item (Join-Path $Root "LICENSE") (Join-Path $Stage "LICENSE")
    Copy-Item (Join-Path $PSScriptRoot "README-BINARY.txt") (Join-Path $Stage "README-BINARY.txt")
    Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $Archive -Force
} finally {
    Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "Created $Archive"
