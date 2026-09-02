param(
    [ValidateSet("x64")]
    [string] $Architecture = "x64"
)

$ErrorActionPreference = "Stop"

function Get-VersionOrZero($File) {
    try {
        return [Version] $File.VersionInfo.FileVersion
    } catch {
        return [Version] "0.0.0.0"
    }
}

$programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
$programRoots = @($env:ProgramFiles, $programFilesX86) | Where-Object { $_ }

$vsRoots = @()
$vswhereCandidates = foreach ($programRoot in $programRoots) {
    Join-Path $programRoot "Microsoft Visual Studio\Installer\vswhere.exe"
}
$vswhereCandidates = $vswhereCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Sort-Object -Unique

$vswhereArgSets = @(
    ,@("-all", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Redist.14.Latest", "-property", "installationPath"),
    ,@("-all", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"),
    ,@("-all", "-products", "*", "-property", "installationPath")
)

foreach ($vswhere in $vswhereCandidates) {
    foreach ($argSet in $vswhereArgSets) {
        $vsRoots += & $vswhere @argSet 2>$null
    }
}

foreach ($programRoot in $programRoots) {
    $visualStudioRoot = Join-Path $programRoot "Microsoft Visual Studio"
    if (-not (Test-Path -LiteralPath $visualStudioRoot)) {
        continue
    }

    foreach ($versionRoot in Get-ChildItem -LiteralPath $visualStudioRoot -Directory -ErrorAction SilentlyContinue) {
        foreach ($editionRoot in Get-ChildItem -LiteralPath $versionRoot.FullName -Directory -ErrorAction SilentlyContinue) {
            $vsRoots += $editionRoot.FullName
        }
    }
}

$vsRoots = $vsRoots |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Sort-Object -Unique

$searchRoots = foreach ($vsRoot in $vsRoots) {
    foreach ($subdir in @("VC\Redist\MSVC", "VC\Tools\MSVC")) {
        $path = Join-Path $vsRoot $subdir
        if (Test-Path -LiteralPath $path) {
            $path
        }
    }
}
$searchRoots = $searchRoots | Sort-Object -Unique

$candidates = foreach ($searchRoot in $searchRoots) {
    Get-ChildItem -LiteralPath $searchRoot -Recurse -File -Filter "libomp140.x86_64.dll" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -match "\\$Architecture\\" -and (
                $_.FullName -match "\\Microsoft\.VC\d+\.OpenMP\.LLVM\\" -or
                $_.FullName -match "\\bin\\Host(?:x86|x64)\\$Architecture\\"
            )
        }
}

$runtime = $candidates |
    Sort-Object `
        @{ Expression = { Get-VersionOrZero $_ } },
        @{ Expression = { $_.FullName } } `
        -Descending |
    Select-Object -First 1

if (-not $runtime) {
    $searched = if ($searchRoots) { $searchRoots -join "; " } else { "<none>" }
    throw "MSVC $Architecture libomp140.x86_64.dll not found. Searched: $searched"
}

$runtime.FullName
