param([string] $Version = '0.1.0')

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$package = Join-Path $repo 'dist\lobo-sm120-win64'
if (-not (Test-Path -LiteralPath (Join-Path $package 'runtime\llama-server.exe'))) { throw 'Build the package first.' }

& (Join-Path $repo 'tools\verify-release.ps1') -ReleaseRoot $package -WriteManifest
if ($LASTEXITCODE -ne 0) { throw 'Release verification failed.' }

$zip = Join-Path $repo ("dist\lobo-sm120-win64-v$Version.zip")
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
Write-Host "ZIP: $zip"
Write-Host "SHA-256: $hash"
