# Windows installation

## Qualified environment

- Windows 11, WDDM
- NVIDIA RTX 5070 Ti 16 GB, SM120
- NVIDIA driver compatible with CUDA 13.3
- CUDA Toolkit 13.3
- Visual Studio 2022 Build Tools, Desktop development with C++
- Microsoft Visual C++ 2015-2022 x64 Redistributable (for the prebuilt ZIP)
- CMake 3.28 or newer
- Git and PowerShell 7
- Python 3.11 or newer for benchmark tooling

The source may compile elsewhere because it inherits upstream code, but no other OS, GPU, or CUDA release is supported by the published appliance measurements.

The ZIP contains Lobo's own executable/DLL closure. System DLLs, the MSVC/OpenMP runtime (`VCRUNTIME140`, `MSVCP140`, `VCOMP140`), and NVIDIA CUDA/cuBLAS (`cublas64_13`) remain external prerequisites. A source-build machine with the qualified Visual Studio and CUDA installations already has these components; a binary-only machine must install the x64 Visual C++ redistributable and CUDA Toolkit 13.3 separately.

## Build

From a normal PowerShell terminal:

```powershell
git clone https://github.com/alectodescent/lobo-qwen38-16gb.git
cd lobo-qwen38-16gb
.\build\build-sm120.ps1
.\build\verify-build.ps1
```

The build script locates Visual Studio with `vswhere`, configures the source in `_build\sm120`, and places the releasable binaries in `dist\lobo-sm120-win64`. It does not use machine-specific absolute paths.

## Prebuilt ZIP

Download `lobo-sm120-win64-v0.1.1.zip` from this repository's latest GitHub Release, then extract it to a new directory. The archive is self-contained apart from the documented Microsoft and NVIDIA runtimes and the separately obtained model file.

```powershell
Expand-Archive .\lobo-sm120-win64-v0.1.1.zip -DestinationPath .\lobo
Set-Location .\lobo
.\runtime\llama-server.exe --version
```

Put the verified model files in that extracted directory's `models\` folder. Its packaged launchers automatically find the packaged server and model directory.

## Models

Download and verify the single Balanced/MTP model:

```powershell
.\tools\download-balanced-model.ps1
.\tools\verify-model.ps1 -Profile Balanced
```

The two-source assembler remains available in [MODEL_FILES.md](MODEL_FILES.md) for reproducibility.

Verification is intentionally strict. A same-named file with a different hash is not the frozen appliance.

## Launch

```powershell
# Recommended long-context profile
.\launchers\run-balanced-230k.ps1

# Or target-only native context
.\launchers\run-max-context-262k.ps1

# Or full-context bounded MTP when the 5070 Ti is effectively headless
.\launchers\run-mtp-headless-262k.ps1
```

Every launcher accepts `-ModelPath`, `-ServerPath`, and `-Port`. Defaults are repository-relative. Example:

```powershell
.\launchers\run-balanced-230k.ps1 -ModelPath D:\Models\lobo-mtp.gguf -Port 8080
```

## VRAM discipline

Close GPU-heavy applications before 230K/262K runs. Display composition on the 5070 Ti consumes the same dedicated memory needed by the model. Moving displays to an integrated GPU can improve headroom. Do not interpret nonlocal/shared WDDM commitment as harmless if it grows with live depth: paging causes a severe throughput collapse.

The launchers bind to `127.0.0.1`; exposing the server to a network requires your own authentication and firewall policy.
