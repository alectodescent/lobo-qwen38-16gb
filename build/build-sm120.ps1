param(
    [switch] $Clean,
    [int] $Jobs = [Environment]::ProcessorCount
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $repo 'runtime'
$build = Join-Path $repo '_build\sm120'
$package = Join-Path $repo 'dist\lobo-sm120-win64'

if (-not (Test-Path -LiteralPath (Join-Path $source 'CMakeLists.txt') -PathType Leaf)) {
    throw "Runtime source not found: $source"
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) { throw 'vswhere.exe was not found. Install Visual Studio 2022 Build Tools.' }
$vs = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if (-not $vs) { throw 'Visual Studio C++ build tools were not found.' }
$devcmd = Join-Path $vs 'Common7\Tools\VsDevCmd.bat'

# Import the VS developer environment without relying on a local machine path.
$environment = & $env:ComSpec /s /c "`"$devcmd`" -arch=x64 -host_arch=x64 >nul && set"
if ($LASTEXITCODE -ne 0) { throw 'Failed to initialize the Visual Studio developer environment.' }
foreach ($line in $environment) {
    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) { [Environment]::SetEnvironmentVariable($parts[0], $parts[1], 'Process') }
}

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { throw 'CMake was not found on PATH.' }
if (-not (Get-Command nvcc -ErrorAction SilentlyContinue)) { throw 'CUDA nvcc was not found on PATH.' }

if ($Clean -and (Test-Path -LiteralPath $build)) {
    $resolvedRepo = [IO.Path]::GetFullPath($repo).TrimEnd('\') + '\'
    $resolvedBuild = [IO.Path]::GetFullPath($build)
    if (-not $resolvedBuild.StartsWith($resolvedRepo, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to remove a build directory outside the repository.' }
    Remove-Item -LiteralPath $resolvedBuild -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $build | Out-Null
$configure = @(
    '-S', $source, '-B', $build, '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_CUDA_ARCHITECTURES=120',
    '-DGGML_CUDA=ON', '-DGGML_CUDA_FA=ON', '-DGGML_CUDA_FA_ALL_QUANTS=OFF',
    '-DGGML_CUDA_KVARN=ON', '-DGGML_CUDA_GRAPHS=ON', '-DGGML_NATIVE=ON',
    '-DGGML_CPU=ON', '-DGGML_CPU_ALL_VARIANTS=OFF', '-DGGML_RPC=OFF',
    '-DGGML_CCACHE=OFF', '-DBUILD_SHARED_LIBS=ON',
    '-DLLAMA_BUILD_SERVER=ON', '-DLLAMA_BUILD_TESTS=ON',
    '-DLLAMA_BUILD_TOOLS=ON', '-DLLAMA_BUILD_EXAMPLES=OFF', '-DLLAMA_BUILD_APP=OFF',
    # The appliance binds to localhost and does not ship an OpenSSL DLL closure.
    '-DLLAMA_LLGUIDANCE=OFF', '-DLLAMA_OPENSSL=OFF',
    '-DLLAMA_USE_PREBUILT_UI=ON', '-DLLAMA_BUILD_IS_DEV=ON'
)
& cmake @configure
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed: $LASTEXITCODE" }
& cmake --build $build --target llama-server test-kvarn test-backend-ops --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }

$bin = Join-Path $build 'bin'
if (-not (Test-Path -LiteralPath (Join-Path $bin 'llama-server.exe'))) { throw 'Build completed without llama-server.exe.' }
$resolvedRepo = [IO.Path]::GetFullPath($repo).TrimEnd('\') + '\'
$resolvedPackage = [IO.Path]::GetFullPath($package)
if (-not $resolvedPackage.StartsWith($resolvedRepo, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to stage a package outside the repository.' }
if (Test-Path -LiteralPath $resolvedPackage) { Remove-Item -LiteralPath $resolvedPackage -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $package 'runtime') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $package 'launchers') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $package 'tools') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $package 'benchmarks') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $package 'benchmarks\results') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $package 'models') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $package 'docs') | Out-Null

$closure = @('llama-server.exe','ggml-base.dll','ggml-cpu.dll','ggml-cuda.dll','ggml.dll','llama-common.dll','llama-server-impl.dll','llama.dll','mtmd.dll')
foreach ($name in $closure) {
    $path = Join-Path $bin $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required runtime file missing: $path" }
    Copy-Item -LiteralPath $path -Destination (Join-Path $package 'runtime') -Force
}
Copy-Item -Path (Join-Path $repo 'launchers\*.ps1') -Destination (Join-Path $package 'launchers') -Force
Copy-Item -LiteralPath (Join-Path $repo 'tools\verify-model.ps1') -Destination (Join-Path $package 'tools') -Force
Copy-Item -LiteralPath (Join-Path $repo 'tools\verify-release.ps1') -Destination (Join-Path $package 'tools') -Force
Copy-Item -LiteralPath (Join-Path $repo 'tools\assemble-mtp-pack.py') -Destination (Join-Path $package 'tools') -Force
Copy-Item -LiteralPath (Join-Path $repo 'tools\monitor-vram.ps1') -Destination (Join-Path $package 'tools') -Force
Copy-Item -Path (Join-Path $repo 'benchmarks\*.py') -Destination (Join-Path $package 'benchmarks') -Force
Copy-Item -LiteralPath (Join-Path $repo 'benchmarks\spatial-firewall-v1.json') -Destination (Join-Path $package 'benchmarks') -Force
Copy-Item -Path (Join-Path $repo 'benchmarks\results\*') -Destination (Join-Path $package 'benchmarks\results') -Force
Copy-Item -LiteralPath (Join-Path $repo 'models\README.md') -Destination (Join-Path $package 'models') -Force
Copy-Item -Path (Join-Path $repo 'docs\*.md') -Destination (Join-Path $package 'docs') -Force
Copy-Item -LiteralPath (Join-Path $repo 'THIRD_PARTY_NOTICES.md') -Destination $package -Force
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination $package -Force
Copy-Item -LiteralPath (Join-Path $repo 'CHANGELOG.md') -Destination $package -Force
Copy-Item -LiteralPath (Join-Path $repo 'SECURITY.md') -Destination $package -Force
Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination (Join-Path $package 'README.txt') -Force

Write-Host "Built and staged: $package"
