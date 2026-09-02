# Performance notes

## Retained matched improvements

The public source snapshot contains the final retained SM120 IQ-family MMV specialization. Matched before/after measurements on the qualified machine were:

| Workload | Before | After | Change |
| --- | ---: | ---: | ---: |
| target-only, 8K | 38.08 tok/s | 39.04 tok/s | +2.51% |
| MTP n=2, 8K | 72.12 tok/s | 77.71 tok/s | +7.76% |
| DFlash2 n=4, 8K | 87.05 tok/s | 89.36 tok/s | +2.65% |
| Balanced MTP, literal ~230K | 35.94 tok/s | 36.26 tok/s | +0.89% |

Different rows may use different prompt fixtures. Use the percentage only within each matched pair; do not compare absolute rates between fixtures as if prompt work were identical.

Important verification kernels improved by about 17% for IQ3_S and 14.7% for IQ3_XXS. Several more aggressive kernel ideas were reverted after regressions or sub-1% gains; the public source is the clean retained state.

## Where time goes

Nsight traces of the qualified runtime show a context-dependent split:

| Live depth | Quantized weight MMV | KVarN attention | Interpretation |
| ---: | ---: | ---: | --- |
| ~8K | 65.22% | 10.51% | weight execution dominates |
| ~128K | 41.39% | 43.06% | weight and attention are co-dominant |

At ~128K, the KVarN scan itself was 36.19% and the stable split/combine path 4.16%. Shallow performance therefore responds most to packed-weight execution; very-long-context performance needs both faster weight MMV and faster cache scanning/reduction.

These are traced kernel-time shares, not a claim about achieved DRAM bandwidth. No public bandwidth percentage is stated without hardware-counter evidence.

## Representative shallow results

With batch 256/ubatch 32 on the retained source:

| Context | Target-only | MTP n=2 | DFlash2 n=4 |
| ---: | ---: | ---: | ---: |
| 2K | 40.03 | 75.63 | 93.07 |
| 8K | 38.28 | 75.20 | 87.58 |
| 32K | 28.85 | 70.44 | 73.20 |

These are controlled fixture results in committed tokens/second. DFlash's sidecar explains why it is a Turbo profile rather than the context-maximizing default.

## Long context

The final Balanced long-binding run used an actually populated prompt at approximately 230K, not merely a large allocated cache. It measured 186.71 prompt tok/s and 36.26 committed decode tok/s, recovered all required bindings, and stayed resident.

Historical old-Lobo figures sometimes mixed allocation capacity with live depth. In particular, the old “~63 tok/s at ~239K” observation allocated a large cache but did not decode at a genuinely populated 239K position. The old real live-depth curve is reproduced in [Benchmarks](BENCHMARKS.md).

