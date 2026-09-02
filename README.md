# Lobo — Qwen3.8-27B on a single 16 GB RTX 5070 Ti

Lobo is an SM120-specialized inference appliance for running Qwen3.8-27B locally on one RTX 5070 Ti 16 GB. It combines GSQ-RCO IQ3_S weights, a native packed KVarN K4V2 cache, a bounded 256-token MTP draft cache, and retained Blackwell IQ-family MMV specialization.

This release targets Windows 11, CUDA 13.3, an RTX 5070 Ti, and batch-one serving. It is deliberately model- and GPU-specific. Other hardware and operating systems are not qualified.

## What it provides

| Profile | Allocated context | Speculation | Representative measured decode | Purpose |
| --- | ---: | --- | ---: | --- |
| Maximum Context | 262,144 | none | capacity qualified; live-depth curve in docs | full native context |
| Headless MTP | 262,144 | MTP n=2, 256-token K2V2 draft cache | use clean qualification curves; near-zero desktop residency required | full native context with bounded speculation |
| Balanced | 230,144 | MTP n=2, 256-token K2V2 draft cache | 36.26 tok/s at literal ~230K | recommended long-context mode |
| MTP Short | 8K | MTP n=2 | 77.71 tok/s matched retained build | normal resident workloads |
| Turbo / DFlash | 8K | DFlash2 n=4 | 89.36 tok/s matched retained build | optional shallow-context speed |

Absolute rates depend on prompt shape, generated text, driver state, clocks, and desktop VRAM use. The 8K figures are matched A/B measurements; they must not be compared directly with unrelated prompts. The controlled depth curve and long-binding qualification are documented separately in [Benchmarks](docs/BENCHMARKS.md).

## Why this is different from normal llama.cpp

- KVarN K4 and V2 are stored as independent, unpadded records. This avoids a 640 MiB padding tax at 262,144 context.
- Only Qwen3.8's 16 full-attention layers allocate KV; its 48 recurrent/GDN layers retain recurrent state instead.
- The canonical numerical path uses an SM120 tile width of two.
- Balanced MTP uses `n=2`, KVarN K2V2 draft KV, and an exact 256-token draft window. The draft cache never scales to target context.
- The retained CUDA specialization covers the IQ-family MMV formats used by the frozen model and MTP block.
- DFlash2 remains a separate Turbo mode because its sidecar trades context capacity for speed.

See [Architecture](docs/ARCHITECTURE.md) and [Profiles](docs/PROFILES.md) before changing these choices.

## Quick start

Source-build prerequisites: Windows 11, an RTX 5070 Ti with a current NVIDIA driver, CUDA Toolkit 13.3, CMake, Git, Python 3.11+, and Visual Studio 2022 Build Tools with the C++ workload. The prebuilt ZIP instead needs the Microsoft Visual C++ 2015-2022 x64 Redistributable plus CUDA Toolkit 13.3.

```powershell
git clone https://github.com/alectodescent/lobo-qwen38-16gb.git
cd lobo-qwen38-16gb
.\build\build-sm120.ps1
```

Obtain and verify the model files described in [Model files](docs/MODEL_FILES.md). Put them in `models\`.

```powershell
.\tools\verify-model.ps1
.\launchers\run-balanced-230k.ps1
```

The server listens on `http://127.0.0.1:18080`. For the target-only native-context profile:

```powershell
.\launchers\run-max-context-262k.ps1
```

When the 5070 Ti is effectively headless and has near-zero desktop residency, the same bounded-MTP architecture can allocate the full native context:

```powershell
.\launchers\run-mtp-headless-262k.ps1
```

Detailed setup and troubleshooting are in [Windows installation](docs/INSTALL_WINDOWS.md).

## Frozen configuration

- Qwen source revision: `1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0`
- GSQ-RCO source revision: `d562806dbafae37109975e970aae91b43e73b440`
- canonical GSQ-RCO IQ3_S: 11,771,546,784 bytes
- Lobo MTP deployment pack: 11,975,960,640 bytes
- target KV: KVarN K4V2 G128, 13,824 bytes per model-token
- target geometry: 16 full-attention layers, 4 KV heads, head dimension 256, GQA6
- Balanced: context 230,144, batch 64, ubatch 16, MTP n=2, draft context 256
- Headless MTP: context 262,144, batch 64, ubatch 16, MTP n=2, draft context 256
- Maximum Context: context 262,144, batch 256, ubatch 32, target-only

## Source and licenses

The runtime is an MIT-licensed derivative of [llama.cpp](https://github.com/ggml-org/llama.cpp), [Anbeeld/beellama.cpp](https://github.com/Anbeeld/beellama.cpp), and [valujin/beellama-kvarn](https://github.com/valujin/beellama-kvarn). Upstream notices and vendored dependency licenses are preserved. Qwen and GSQ model files are not part of this repository or the binary release. See [Third-party notices](THIRD_PARTY_NOTICES.md).

## Status and limits

Lobo is a technical appliance, not a general support fork. The published numbers are qualified only on the stated machine class. WDDM display usage can reduce the available context, especially for DFlash. Vision is not part of this release's behavioural qualification. Report security issues using [SECURITY.md](SECURITY.md) and reproducible runtime defects through GitHub Issues.
