param(
    [string] $ModelDirectory = (Join-Path $PSScriptRoot '..\models'),
    [ValidateSet('Balanced','MaximumContext','Turbo','All')][string] $Profile = 'Balanced'
)

$ErrorActionPreference = 'Stop'
$ModelDirectory = [IO.Path]::GetFullPath($ModelDirectory)
$requiredRoles = @{
    Balanced = @('mtp')
    MaximumContext = @('base')
    Turbo = @('base','dflash')
    All = @('base','mtp','dflash')
}[$Profile]
$known = @(
    [pscustomobject]@{ Role='base'; Name='Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf'; Bytes=11771546784L; Sha256='64b53b64c7aa39f20a7e54bd80582fe595b1d745624ee8a72e92508c0326d810' },
    [pscustomobject]@{ Role='mtp'; Name='Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf'; Bytes=11975960640L; Sha256='4eb8482539194ed9bc1555c88613f39f2e65db37b16d9ab173f908e78d454512' },
    [pscustomobject]@{ Role='dflash'; Name='Qwen3.8-27B-DFlash2-Q4_K_M.gguf'; Bytes=1143006752L; Sha256='18a380efc9b7ed8d88677fc895f5c11ae170653434ee378f7348f715c14d0594' }
)

$found = 0
foreach ($item in $known) {
    $required = $requiredRoles -contains $item.Role
    $path = Join-Path $ModelDirectory $item.Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $label = if ($required) { 'MISSING REQUIRED' } else { 'not installed (optional)' }
        Write-Host "$label  $($item.Name)"
        if ($required) { $script:missing = $true }
        continue
    }
    $file = Get-Item -LiteralPath $path
    if ($file.Length -ne $item.Bytes) { throw "Wrong byte count for $($item.Name): $($file.Length), expected $($item.Bytes)" }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($hash -ne $item.Sha256) { throw "Wrong SHA-256 for $($item.Name): $hash" }
    Write-Host "OK  $($item.Name)"
    $found++
}
if ($script:missing) { exit 1 }
Write-Host "Verified $found installed model artifact(s); profile $Profile is complete."
