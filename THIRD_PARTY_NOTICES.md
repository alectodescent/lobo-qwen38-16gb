# Third-party notices

Lobo is a modified inference-runtime distribution, not wholly original software. The source snapshot in `runtime/` retains upstream copyright headers, `AUTHORS`, `LICENSE`, and dependency notices.

## Runtime lineage

- **ggml-org/llama.cpp and ggml** — MIT License. Source: <https://github.com/ggml-org/llama.cpp>.
- **Anbeeld/beellama.cpp** — MIT License; fork of llama.cpp with Qwen/KVarN work. Source: <https://github.com/Anbeeld/beellama.cpp>.
- **valujin/beellama-kvarn** — MIT-licensed derivative used as the immediate public KVarN source lineage. Source: <https://github.com/valujin/beellama-kvarn>.
- **DFlash2 runtime support** — derived from public llama.cpp pull request 27342, donor commit `5ecbe1ac17ec0484c5b44af0bd580cdc9c428ed4`, under the llama.cpp MIT license.

## Vendored components

The runtime tree preserves its original license files, including Apache-2.0 with LLVM exception material, OpenVINO notices, nlohmann/json, cpp-httplib, SHA-256, rotate-bits, and xxHash notices. Consult `runtime/licenses/`, `runtime/vendor/`, and source-file headers before redistributing a modified build.

## Models and data — not distributed here

- **Qwen/Qwen3.8-27B** — Apache-2.0 according to the upstream model card, pinned revision `1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0`.
- **ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF** — Apache-2.0 repository metadata; its card says the weights inherit the base Qwen license.
- **Unsloth Qwen3.8 GGUF donor** — Apache-2.0 repository metadata; separately obtained model artifact used only to reconstruct the local MTP pack.
- **z-lab Qwen3.8 DFlash2** — Apache-2.0 repository metadata; separately obtained optional draft artifact.

No GGUF model, BF16 teacher data, calibration corpus, or private prompt data is included in this source repository or binary ZIP. Exact artifact provenance is in `docs/MODEL_FILES.md`.

## Binary package

The release ZIP contains only binaries produced from this source tree, public launch/verification scripts, and notices. CUDA, cuBLAS, the NVIDIA driver, and Microsoft Visual C++ runtime components are external prerequisites and are not bundled.
