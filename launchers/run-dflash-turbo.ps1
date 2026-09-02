param(
    [string] $ModelPath = (Join-Path $PSScriptRoot '..\models\Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf'),
    [string] $DraftModelPath = (Join-Path $PSScriptRoot '..\models\Qwen3.8-27B-DFlash2-Q4_K_M.gguf'),
    [string] $ServerPath = '',
    [ValidateRange(1024, 163840)][int] $Context = 131072,
    [int] $Port = 18080,
    [int] $Threads = 16,
    [string] $SlotSavePath = ''
)

$ErrorActionPreference = 'Stop'
$ModelPath = [IO.Path]::GetFullPath($ModelPath)
$DraftModelPath = [IO.Path]::GetFullPath($DraftModelPath)
if (-not $ServerPath) {
    $packaged = Join-Path $PSScriptRoot '..\runtime\llama-server.exe'
    $ServerPath = if (Test-Path -LiteralPath $packaged) { $packaged } else { Join-Path $PSScriptRoot '..\dist\lobo-sm120-win64\runtime\llama-server.exe' }
}
$ServerPath = [IO.Path]::GetFullPath($ServerPath)
foreach ($path in @($ServerPath, $ModelPath, $DraftModelPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file not found: $path" }
}

$env:GGML_KVARN_Q_TILE = '2'
$env:LLAMA_MTP_N_CTX = $null
$env:LLAMA_MTP_SKIP_PREFILL = $null

$serverArgs = @(
    '-m', $ModelPath, '-c', "$Context", '-b', '256', '-ub', '32',
    '-ctk', 'kvarn4', '-ctv', 'kvarn2', '--kv-tail-tokens', '0',
    '-t', "$Threads", '-ngl', 'all', '-fit', 'off', '-fa', 'on',
    '--no-mmap', '--no-warmup', '--host', '127.0.0.1', '--port', "$Port",
    '-np', '1', '--no-ui', '--cache-prompt', '--cache-ram', '0',
    '--ctx-checkpoints', '1', '--no-cache-idle-slots', '--no-host',
    '--spec-type', 'draft-dflash', '--spec-draft-model', $DraftModelPath,
    '--spec-draft-ngl', 'all', '--spec-draft-n-max', '4',
    '--spec-draft-type-k', 'f16', '--spec-draft-type-v', 'f16',
    '--log-colors', 'off'
)
if ($SlotSavePath) {
    $SlotSavePath = [IO.Path]::GetFullPath($SlotSavePath)
    New-Item -ItemType Directory -Force -Path $SlotSavePath | Out-Null
    $serverArgs += @('--slot-save-path', $SlotSavePath)
}
& $ServerPath @serverArgs
exit $LASTEXITCODE
