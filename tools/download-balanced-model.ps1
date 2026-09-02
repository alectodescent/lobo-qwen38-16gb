param(
    [string] $ModelDirectory = (Join-Path $PSScriptRoot '..\models')
)

$ErrorActionPreference = 'Stop'
$name = 'Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf'
$expectedBytes = 11975960640L
$expectedSha256 = '4eb8482539194ed9bc1555c88613f39f2e65db37b16d9ab173f908e78d454512'
$url = 'https://huggingface.co/Farggin/Lobo-Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-GGUF/resolve/main/Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf?download=true'

$ModelDirectory = [IO.Path]::GetFullPath($ModelDirectory)
New-Item -ItemType Directory -Force -Path $ModelDirectory | Out-Null
$destination = Join-Path $ModelDirectory $name
$partial = "$destination.partial"

function Test-FrozenArtifact([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -ne $expectedBytes) { return $false }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return $hash -eq $expectedSha256
}

if (Test-FrozenArtifact $destination) {
    Write-Host "Already verified: $destination"
    exit 0
}
if (Test-Path -LiteralPath $destination) {
    throw "A wrong-sized or wrong-hash destination already exists: $destination"
}
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    throw 'curl.exe is required. It is included with supported Windows 11 installations.'
}

Write-Host "Downloading $name"
Write-Host 'The transfer is approximately 12.0 GB and resumes from an existing .partial file.'
& curl.exe --location --fail --retry 5 --retry-delay 2 --continue-at - --output $partial $url
if ($LASTEXITCODE -ne 0) { throw "Download failed with curl exit code $LASTEXITCODE. Run this script again to resume." }

$download = Get-Item -LiteralPath $partial
if ($download.Length -ne $expectedBytes) {
    throw "Downloaded byte count is $($download.Length), expected $expectedBytes. Run this script again to resume."
}
$hash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne $expectedSha256) {
    throw "Downloaded SHA-256 is $hash, expected $expectedSha256. The partial file was retained for inspection."
}

Move-Item -LiteralPath $partial -Destination $destination
Write-Host "Verified: $destination"
Write-Host "SHA-256: $expectedSha256"
