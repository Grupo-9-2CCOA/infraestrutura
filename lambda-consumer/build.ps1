param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root "lambda-src"
$build = Join-Path $root "build"
$zip = Join-Path $root "lambda.zip"

if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Path $build | Out-Null

& $Python -m pip install --quiet --upgrade --target $build -r (Join-Path $src "requirements.txt")
if ($LASTEXITCODE -ne 0) { throw "pip install failed" }

Copy-Item (Join-Path $src "handler.py") $build

Get-ChildItem -Path $build -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force

if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $build "*") -DestinationPath $zip -CompressionLevel Optimal

Write-Host "Built $zip"
