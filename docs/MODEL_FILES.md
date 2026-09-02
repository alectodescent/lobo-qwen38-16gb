# Model files

Model weights are not distributed in this repository or binary release. Download the pinned public inputs and verify them before use.

## Maximum Context input

| Field | Value |
| --- | --- |
| Filename | `Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf` |
| Bytes | `11,771,546,784` |
| SHA-256 | `64b53b64c7aa39f20a7e54bd80582fe595b1d745624ee8a72e92508c0326d810` |
| Upstream | `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF` |
| Revision | `d562806dbafae37109975e970aae91b43e73b440` |
| URL | <https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF/blob/d562806dbafae37109975e970aae91b43e73b440/Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf> |
| Upstream license | Apache-2.0 repository metadata; model card says weights inherit Qwen's license |

The underlying BF16 model is `Qwen/Qwen3.8-27B` at revision `1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0`, whose model card identifies Apache-2.0.

## Balanced MTP deployment pack

| Field | Value |
| --- | --- |
| Filename | `Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf` |
| Bytes | `11,975,960,640` |
| Decimal GB / GiB | `11.975960640 GB` / `11.153482497 GiB` |
| SHA-256 | `4eb8482539194ed9bc1555c88613f39f2e65db37b16d9ab173f908e78d454512` |
| Base | the exact GSQ file above |
| MTP donor | `unsloth/Qwen3.8-27B-GGUF`, revision `f975863083b62f54a5e6fac11671c750c2bbc59c` |
| Donor filename | `Qwen3.8-27B-UD-IQ3_XXS.gguf` |
| Donor bytes | `11,913,559,104` |
| Donor SHA-256 | `0a6129dcbbbe72f423dc67e0e3bbfbbdf3e923981a3637687ebb96a46c59d6be` |
| Donor URL | <https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/blob/f975863083b62f54a5e6fac11671c750c2bbc59c/Qwen3.8-27B-UD-IQ3_XXS.gguf> |
| Donor repository license | Apache-2.0 |

The deployment pack is a deterministic local assembly: all 851 base tensor payloads are byte-identical to GSQ; the 15 `blk.64.*` MTP tensor payloads are byte-identical to the pinned donor. The added MTP payload is 204,412,928 bytes. Large MTP weights are IQ4_XS/IQ3_S; small normalization tensors remain F32. Use `tools/assemble-mtp-pack.py` and require the exact output hash above.

```powershell
python .\tools\assemble-mtp-pack.py `
  --base .\models\Qwen3.8-27B-GSQ-RCO-IQ3_S.gguf `
  --donor .\models\Qwen3.8-27B-UD-IQ3_XXS.gguf `
  --output .\models\Qwen3.8-27B-GSQ-RCO-IQ3_S-MTP-Q4XS-Q3S.gguf
```

## Optional DFlash2 sidecar

| Field | Value |
| --- | --- |
| Filename | `Qwen3.8-27B-DFlash2-Q4_K_M.gguf` |
| Bytes | `1,143,006,752` |
| SHA-256 | `18a380efc9b7ed8d88677fc895f5c11ae170653434ee378f7348f715c14d0594` |
| Upstream | `z-lab/Qwen3.8-27B-DFlash2-GGUF` |
| Revision | `cb9dfae3f326836ac2557ed653c84478a0392972` |
| URL | <https://huggingface.co/z-lab/Qwen3.8-27B-DFlash2-GGUF/blob/cb9dfae3f326836ac2557ed653c84478a0392972/Qwen3.8-27B-DFlash2-Q4_K_M.gguf> |
| Upstream repository license | Apache-2.0 |

The sidecar is not bundled because it adds 1.143 GB to a runtime package and the public upstream already provides the exact pinned object. Obtain it directly from upstream. It is optional and is not required for Maximum Context or Balanced.

## Verification

```powershell
.\tools\verify-model.ps1 -Profile Balanced
.\tools\verify-model.ps1 -Profile MaximumContext
.\tools\verify-model.ps1 -Profile Turbo
```

The default profile is `Balanced`. The verifier checks that profile's required filenames, exact byte counts, and SHA-256 values; `-Profile All` requires every documented artifact. Do not substitute newer files from the same repositories without rerunning the behavioural and token-identity firewalls.
