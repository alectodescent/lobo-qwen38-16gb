# Architecture

## Frozen appliance

Lobo serves the dense Qwen3.8-27B hybrid model on one 16 GB RTX 5070 Ti. It does not change the model's architecture or output semantics. The deployment uses a GSQ-RCO IQ3_S base, optional embedded MTP tensors, direct packed KVarN attention, and CUDA kernels specialized for SM120.

Qwen3.8 has 64 model layers. Sixteen are full-attention layers (`3, 7, 11, ... 63`); the other 48 are recurrent/GDN layers. Each attention layer has four 256-dimensional KV heads shared by six query heads. Only those 16 layers allocate the target KV cache.

## KVarN target cache

The selected KVarN operating point is K4V2 with group size 128:

- keys: channel-oriented variance normalization, orthonormal Walsh-Hadamard transform, 4-bit RTN codes;
- values: token-oriented variance normalization, orthonormal transform, 2-bit RTN codes;
- 128 unquantized sink tokens required by the method;
- no additional recent-token tail (`--kv-tail-tokens 0`);
- partial 64-dimensional MRoPE is applied before KVarN at the normal Qwen boundary;
- query and key use the same orthonormal transform, preserving QK geometry apart from quantization error;
- the value result is transformed back before the output projection.

The CUDA path reads packed K4/V2 records directly inside attention. It does not materialize a full FP16 cache. `GGML_KVARN_Q_TILE=2` selects the qualified numerical route.

K and V stay physically separate: a 128-token by 128-dimension K slice is 8,192 bytes of codes plus 768 bytes of metadata; V is 4,096 plus 768. For a 256-dimensional KV head this amortizes to 140 bytes for K and 76 bytes for V per token. Rounding the combined 216 bytes to 256 is forbidden because it wastes 640 MiB at native context.

## Bounded MTP

Balanced mode uses the model's embedded NextN/MTP block with `n=2`. Its disposable draft cache is KVarN K2V2 and exactly 256 tokens long. The target still verifies every draft token. Bounding this cache saves 139,771,904 bytes (133.297 MiB) at target context 230,144 compared with scaling it to target context, and prevents the draft state from consuming the long-context budget.

The target and verification paths share tile-two arithmetic. Transactional recurrent rollback, draft rollover, and target/cache state copying are part of the qualified implementation. A 924-token run crossed the bounded draft window three times and produced 924/924 target-identical tokens.

## DFlash2

DFlash2 n=4 is optional. It uses a separate roughly 1.143 GB model and a short F16 draft KV. Its output remains target-verified, but the sidecar substantially reduces target-context capacity on a 16 GB GPU. It is therefore a shallow/normal-context Turbo profile, not the Balanced profile.

## SM120 execution

The release preserves:

- native packed KVarN K4V2 CUDA attention;
- a byte-neutral 16 by 16 KVarN payload swizzle;
- fixed tile-two numerical dispatch;
- IQ2_XXS/IQ2_XS/IQ2_S/IQ3_XXS/IQ3_S/IQ4_XS MMV specialization retained after matched correctness/performance gates;
- Qwen hybrid recurrent-state save, restore, and speculative rollback fixes;
- CUDA graphs where the runtime enables them profitably.

The canonical GGUF remains the weight truth. KVarN is a runtime cache representation and is never serialized into the model file.

