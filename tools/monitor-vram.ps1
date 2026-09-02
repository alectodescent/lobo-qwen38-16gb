param(
    [int] $ProcessId = 0,
    [int] $IntervalMs = 2000,
    [string] $Output = ''
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { throw 'nvidia-smi was not found.' }
$header = 'utc,gpu_util_pct,memory_used_mib,memory_free_mib,power_w,process_id,process_working_set_mib'
if ($Output) { $header | Set-Content -LiteralPath $Output -Encoding utf8NoBOM } else { Write-Output $header }
while ($true) {
    $gpu = (& nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.free,power.draw --format=csv,noheader,nounits | Select-Object -First 1) -split ',' | ForEach-Object { $_.Trim() }
    $ws = ''
    if ($ProcessId -gt 0) {
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if (-not $process) { break }
        $ws = [math]::Round($process.WorkingSet64 / 1MB, 3)
    }
    $line = '{0},{1},{2},{3},{4},{5},{6}' -f ([DateTime]::UtcNow.ToString('o')), $gpu[0], $gpu[1], $gpu[2], $gpu[3], $ProcessId, $ws
    if ($Output) { $line | Add-Content -LiteralPath $Output -Encoding utf8NoBOM } else { Write-Output $line }
    Start-Sleep -Milliseconds $IntervalMs
}

