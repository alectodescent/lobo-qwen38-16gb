param([switch] $SkipBackendMatrix)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bin = Join-Path $repo '_build\sm120\bin'
$server = Join-Path $bin 'llama-server.exe'
$kvarn = Join-Path $bin 'test-kvarn.exe'
$backend = Join-Path $bin 'test-backend-ops.exe'
foreach ($path in @($server, $kvarn, $backend)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Build output missing: $path" }
}

& $server --version
if ($LASTEXITCODE -ne 0) { throw 'llama-server version check failed.' }
& $kvarn
if ($LASTEXITCODE -ne 0) { throw 'KVarN CPU/GPU parity tests failed.' }
if (-not $SkipBackendMatrix) {
    & $backend test -b CUDA0 -o MUL_MAT -p 'type_a=(iq2_xxs|iq2_xs|iq2_s|iq3_xxs|iq3_s|iq4_xs)' --seed 0x4c4f424f
    if ($LASTEXITCODE -ne 0) { throw 'Retained IQ-family CUDA backend matrix failed.' }
}
Write-Host 'Build verification passed.'
