param(
    [string] $ModelPath = (Join-Path $PSScriptRoot '..\models\Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf'),
    [string] $ServerPath = '',
    [int] $Port = 18080,
    [int] $Threads = 16,
    [string] $SlotSavePath = ''
)

$ErrorActionPreference = 'Stop'
$ModelPath = [IO.Path]::GetFullPath($ModelPath)
if (-not $ServerPath) {
    $packaged = Join-Path $PSScriptRoot '..\runtime\llama-server.exe'
    $ServerPath = if (Test-Path -LiteralPath $packaged) { $packaged } else { Join-Path $PSScriptRoot '..\dist\lobo-sm120-win64\runtime\llama-server.exe' }
}
$ServerPath = [IO.Path]::GetFullPath($ServerPath)
if (-not (Test-Path -LiteralPath $ServerPath -PathType Leaf)) { throw "Server not found: $ServerPath" }
if (-not (Test-Path -LiteralPath $ModelPath -PathType Leaf)) { throw "MTP model pack not found: $ModelPath" }

$env:GGML_KVARN_Q_TILE = '2'
$env:GGML_KVARN_TEST_FORCE_PORTABLE_FATTN = $null
$env:GGML_KVARN_DEBUG_ROUTES = $null
$env:LLAMA_MTP_N_CTX = '256'
$env:LLAMA_MTP_SKIP_PREFILL = '1'

$serverArgs = @(
    '-m', $ModelPath, '-c', '262144', '-b', '64', '-ub', '16',
    '-ctk', 'kvarn4', '-ctv', 'kvarn2', '--kv-tail-tokens', '0',
    '-t', "$Threads", '-ngl', 'all', '-fit', 'off', '-fa', 'on',
    '--no-mmap', '--no-warmup', '--host', '127.0.0.1', '--port', "$Port",
    '-np', '1', '--no-ui', '--cache-prompt', '--cache-ram', '0',
    '--ctx-checkpoints', '0', '--no-cache-idle-slots', '--no-host',
    '--spec-type', 'draft-mtp', '--spec-draft-n-max', '2',
    '--spec-draft-type-k', 'kvarn2', '--spec-draft-type-v', 'kvarn2',
    '--log-colors', 'off'
)

if ($SlotSavePath) {
    $SlotSavePath = [IO.Path]::GetFullPath($SlotSavePath)
    New-Item -ItemType Directory -Force -Path $SlotSavePath | Out-Null
    $serverArgs += @('--slot-save-path', $SlotSavePath)
}

# This profile assumes the 5070 Ti is effectively headless. Any meaningful
# WDDM/display residency can force paging and destroy long-context throughput.
& $ServerPath @serverArgs
exit $LASTEXITCODE
