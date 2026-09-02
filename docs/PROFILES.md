# Operating profiles

## Maximum Context

- target-only
- `Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf`
- KVarN K4V2 G128, no extra tail
- context 262,144
- batch 256, ubatch 32
- tile-two numerical path

This is the display-attached native-context profile. It has very little WDDM margin. Use it with the 5070 Ti as free of display/application allocations as practical.

## Headless MTP 262K

- `Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf`
- target KVarN K4V2
- MTP n=2
- draft KVarN K2V2, fixed at exactly 256 tokens
- context 262,144
- batch 64, ubatch 16

This keeps the Balanced speculation architecture at full native context. It requires the 5070 Ti to be effectively headless with near-zero desktop dGPU residency. Extending target cache from 230,144 to 262,144 costs 442,368,000 bytes (421.875 MiB); the bounded draft cache does not grow.

## Balanced

- `Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf`
- target KVarN K4V2
- MTP n=2
- draft KVarN K2V2
- exactly 256 draft-cache tokens
- context 230,144
- batch 64, ubatch 16
- tile-two numerical path

This is the primary recommendation. The bounded draft cache is part of the architecture, not a benchmark shortcut. Do not restore target-sized draft KV.

## MTP Short

The same MTP architecture at a smaller allocated context, using batch 256/ubatch 32. This is the preferred normal-context fast path when long-context residency is not required.

## Turbo / DFlash

- GSQ base target plus separate DFlash2 Q4_K_M sidecar
- DFlash2 n=4
- target KVarN K4V2
- F16 bounded draft cache as supplied by the DFlash runtime
- batch 256, ubatch 32
- recommended initial context 131,072; 163,840 only on a verified headless/low-display-residency system

DFlash trades roughly 1.143 GB of target-context headroom for shallow speed. It is not a replacement for Balanced. On a display-attached 5070 Ti, validate residency with `tools/monitor-vram.ps1`; do not claim a context merely because allocation succeeds.
