# Reproducibility and release boundary

## Source boundary

This repository begins with a fresh public Git history. `runtime/` is a tracked-file export of the frozen optimized runtime snapshot; no private remotes, reflogs, branches, abandoned research commits, raw private reports, or local build products were copied.

The immediate public lineage is MIT-licensed `valujin/beellama-kvarn`, itself based on `Anbeeld/beellama.cpp` and llama.cpp. The Anbeeld snapshot identifies upstream base `a749684` on its `v0.4.4` branch. DFlash runtime support identifies public llama.cpp PR 27342 donor `5ecbe1ac17ec0484c5b44af0bd580cdc9c428ed4`.

## Deterministic inputs

- Qwen BF16 source revision: `1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0`.
- GSQ base, MTP donor, assembled pack, and DFlash sidecar hashes are pinned in [Model files](MODEL_FILES.md).
- KVarN configuration: K4V2 G128, tile two, no additional tail.
- Balanced: context 230,144, batch 64/ubatch 16, MTP n=2, K2V2 draft KV, exactly 256 draft tokens.
- Maximum Context: context 262,144, batch 256/ubatch 32, target-only.

## Clean build gate

The release procedure is:

1. clone the public repository into an empty directory;
2. build with `build/build-sm120.ps1`;
3. run `build/verify-build.ps1` and `tools/verify-release.ps1`;
4. verify model inputs;
5. run backend/KVarN tests, target reload, 8K binding, 32K firewall, 924-token MTP rollover, and literal 230K binding;
6. package only the source-built executable/DLL closure, launchers, notices, and manifest;
7. extract the ZIP into a second empty directory and repeat the binary and smoke checks.

The build directory is inside the clean checkout. Scripts do not consult an earlier source tree or machine-specific path.

## Behavioural invariants

Target-only and MTP greedy streams must match. DFlash must also preserve target greedy output. KVarN parity and reload are hard gates. Numerically reordered CUDA optimizations are retained only after token/behavioural qualification.

