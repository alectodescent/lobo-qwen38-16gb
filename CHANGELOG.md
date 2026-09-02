# Changelog

## 0.1.1 — 2026-09-03

- Added a public single-file Hugging Face distribution of the frozen Lobo MTP deployment pack.
- Added a resumable, hash-verifying Balanced model downloader to source and binary packages.
- Kept the deterministic two-source assembly as the reproducibility fallback.

## 0.1.0 — 2026-09-02

- First sanitized public release with fresh Git history.
- Native unpadded KVarN K4V2 target cache and direct packed CUDA attention.
- SM120 tile-two numerical route and payload swizzle.
- Bounded MTP n=2 with a 256-token KVarN K2V2 draft cache.
- Dedicated 262,144-context bounded-MTP launcher for an effectively headless 5070 Ti.
- Optional DFlash2 n=4 Turbo launcher.
- Retained SM120 IQ-family MMV specialization.
- State save/load, recurrent rollback, and speculative identity fixes.
- Reproducible Windows/CUDA 13.3 build, launch, verification, and benchmark tooling.
