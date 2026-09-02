param(
    [string] $ReleaseRoot = (Join-Path $PSScriptRoot '..\dist\lobo-sm120-win64'),
    [switch] $WriteManifest
)

$ErrorActionPreference = 'Stop'
$ReleaseRoot = [IO.Path]::GetFullPath($ReleaseRoot)
if (-not (Test-Path -LiteralPath $ReleaseRoot -PathType Container)) { throw "Release directory not found: $ReleaseRoot" }
$server = Join-Path $ReleaseRoot 'runtime\llama-server.exe'
if (-not (Test-Path -LiteralPath $server -PathType Leaf)) { throw "llama-server.exe missing: $server" }

$forbiddenNames = Get-ChildItem -LiteralPath $ReleaseRoot -File -Recurse | Where-Object { $_.Extension -in @('.gguf','.ggml') }
if ($forbiddenNames) { throw "Model files must not be redistributed: $($forbiddenNames.FullName -join ', ')" }

$required = @(
    'runtime\llama-server.exe','runtime\ggml-base.dll','runtime\ggml-cpu.dll',
    'runtime\ggml-cuda.dll','runtime\ggml.dll','runtime\llama-common.dll',
    'runtime\llama-server-impl.dll','runtime\llama.dll','runtime\mtmd.dll',
    'LICENSE','THIRD_PARTY_NOTICES.md','README.txt','CHANGELOG.md','SECURITY.md',
    'docs\INSTALL_WINDOWS.md','docs\MODEL_FILES.md','docs\PROFILES.md',
    'launchers\run-balanced-230k.ps1','launchers\run-max-context-262k.ps1',
    'launchers\run-mtp-headless-262k.ps1',
    'tools\verify-model.ps1','tools\assemble-mtp-pack.py','tools\monitor-vram.ps1',
    'benchmarks\run-depth-curve.py','benchmarks\run-long-binding.py',
    'benchmarks\run-rollover.py','benchmarks\run-save-reload.py',
    'benchmarks\run-firewall.py','benchmarks\spatial-firewall-v1.json'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $ReleaseRoot $relative) -PathType Leaf)) { throw "Release file missing: $relative" }
}

$textFiles = Get-ChildItem -LiteralPath $ReleaseRoot -File -Recurse | Where-Object { $_.Extension -in @('.md','.txt','.ps1','.json') -and $_.Name -ne 'MANIFEST.json' }
$fatal = '(?i)(github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|hf_[A-Za-z0-9]{20,}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----|[A-Za-z]:\\Users\\[^\\\s]+|E:\\AI\\)'
$hits = $textFiles | Select-String -Pattern $fatal
if ($hits) { throw "Sensitive/private reference found in release: $($hits[0].Path):$($hits[0].LineNumber)" }

if ($WriteManifest) {
    $files = Get-ChildItem -LiteralPath $ReleaseRoot -File -Recurse | Where-Object { $_.Name -ne 'MANIFEST.json' } | Sort-Object FullName
    $entries = foreach ($file in $files) {
        [ordered]@{
            file = [IO.Path]::GetRelativePath($ReleaseRoot, $file.FullName).Replace('\','/')
            size = $file.Length
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        }
    }
    $manifest = [ordered]@{
        schema_version = 1
        generated_utc = [DateTime]::UtcNow.ToString('o')
        package = 'lobo-sm120-win64'
        public_source_commit = (& git -C (Join-Path $PSScriptRoot '..') rev-parse HEAD 2>$null | Select-Object -First 1)
        model_files_excluded = $true
        frozen_model_sha256 = [ordered]@{
            gsq_base = '64b53b64c7aa39f20a7e54bd80582fe595b1d745624ee8a72e92508c0326d810'
            mtp_pack = '4eb8482539194ed9bc1555c88613f39f2e65db37b16d9ab173f908e78d454512'
            dflash_optional = '18a380efc9b7ed8d88677fc895f5c11ae170653434ee378f7348f715c14d0594'
        }
        files = @($entries)
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ReleaseRoot 'MANIFEST.json') -Encoding utf8NoBOM
}

& $server --version
if ($LASTEXITCODE -ne 0) { throw 'Packaged server failed to start for version check.' }
Write-Host 'Release structure, dependency closure, and privacy checks passed.'
