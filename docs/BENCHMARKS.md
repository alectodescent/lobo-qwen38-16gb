# Benchmarks

## Methodology

Every result must state both allocated context and target live depth. Throughput from a cache-residency smoke is not a full-depth decode result. The harness records model/runtime hashes, batch shape, prompt and committed decode rates, draft acceptance, wall time, GPU memory, and process RAM.

Three workload classes are kept separate:

1. **Synthetic / controlled systems benchmark** — deterministic filler and a fixed terminal task, used to measure scaling.
2. **Long-binding qualification** — four bindings are injected across a long context and must be recovered exactly.
3. **Normal generation** — prose/code prompts with enough output to suppress startup noise.

The rollover gate generates more than 768 tokens and compares the entire greedy target-only and MTP token streams. The qualified 924-token fixture crossed the 256-token draft boundary three times and matched 924/924 target tokens.

## Frozen public reference

Machine: RTX 5070 Ti 16 GB, Windows 11/WDDM, CUDA 13.3, Ryzen 7 7800X3D, 32 GB RAM. See `benchmarks/results/frozen-reference.json` for machine-readable values and hashes.

| Qualification | Result |
| --- | --- |
| backend retained IQ matrix | 98/98 passed |
| KVarN CPU/GPU direct parity | passed |
| state save/reload and transactional copy | passed |
| 32K 12-case behavioural firewall | all generated token streams matched frozen target; strict parser pattern 5/12 |
| literal 230K long-binding | passed; 36.2569 tok/s decode; 186.7059 tok/s prefill |
| 924-token MTP rollover | 924/924 identical; 90.1129 vs 47.9722 tok/s; 612/621 drafts accepted |

## Controlled retained curve

The currently available full controlled curve used batch 64/ubatch 16. It is a systems fixture, not a claim about arbitrary real prompts.

| Live depth | Target-only | MTP n=2 | DFlash2 n=4 |
| ---: | ---: | ---: | ---: |
| 2K | 39.56 | 74.59 | 93.31 |
| 8K | 37.87 | 72.33 | 86.91 |
| 16K | 37.23 | 70.61 | 83.71 |
| 32K | 28.28 | 67.61 | 72.60 |
| 64K | 21.55 | 59.86 | 64.94 |
| 128K | 14.42 | 47.05 | 49.62 |

Token identity held through 64K. At 128K all three arms shared the same fixture-level semantic failure, so that point remains a throughput measurement rather than a successful binding qualification.

## Historical old-Lobo live-depth curve

This is retained only to prevent a capacity/depth comparison error:

| Live depth | Old MTP tok/s |
| ---: | ---: |
| 0.5K | 78.84 |
| 4K | 69.26 |
| 16K | 61.52 |
| 32K | 45.86 |
| 65K | 35.87 |
| 98K | 27.90 |
| 131K | 24.73 |
| 224K | 21.96 |
| 238.7K | 21.38 |

## Running the harness

```powershell
python .\benchmarks\run-depth-curve.py --profile target --depths 2048 8192 16000 32000
python .\benchmarks\run-long-binding.py --profile balanced --depth 230000
python .\benchmarks\run-normal-generation.py --profile mtp --depths 2048 8192 32000
python .\benchmarks\run-firewall.py --profile target --output target-firewall.json
.\launchers\run-max-context-262k.ps1 -Context 1152
python .\benchmarks\run-rollover.py --profile target --tokens 924 --output target-rollover.json
# Stop the target server, then:
.\launchers\run-mtp-short.ps1 -Context 1152
python .\benchmarks\run-rollover.py --profile mtp --tokens 924 --reference target-rollover.json
python .\benchmarks\run-save-reload.py --profile mtp
```

The save/reload gate requires the server to be launched with `-SlotSavePath <directory>`. It saves a populated hybrid/KVarN slot, advances it, restores the snapshot, and requires the entire greedy replay to be token-identical.

By default results go to `benchmarks\results\local-*`, which Git ignores. Large logs stay outside the source tree when `--output-root` is set to another drive.
