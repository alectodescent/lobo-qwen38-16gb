# Memory accounting

## Files

| Artifact | Bytes | Decimal GB | GiB | Included in release ZIP |
| --- | ---: | ---: | ---: | --- |
| GSQ-RCO IQ3_S base | 11,771,546,784 | 11.771547 | 10.962175 | no |
| Lobo GSQ plus MTP deployment pack | 11,975,960,640 | 11.975961 | 11.153482 | no |
| Optional DFlash2 Q4_K_M sidecar | 1,143,006,752 | 1.143007 | 1.064508 | no |

The binary release size and DLL closure are recorded in its `MANIFEST.json`. CUDA/cuBLAS and the MSVC runtime are external prerequisites.

## Target KVarN storage

For each 128-token by 128-dimension slice:

| Record | Codes | Metadata | Total |
| --- | ---: | ---: | ---: |
| K4 | 8,192 B | 768 B | 8,960 B |
| V2 | 4,096 B | 768 B | 4,864 B |

A 256-dimensional KV head contains two slices, giving 140 bytes K plus 76 bytes V per head-token. Four KV heads across 16 attention layers give a frozen payload slope of **13,824 bytes per model-token**.

The runtime also reserves 33,619,968 bytes of persistent KVarN state: 8.0625 MiB for exact overlay/sink state and 24 MiB staging. Target-cache residency is therefore `33,619,968 + 13,824 * context`.

| Context | Target KV bytes | MiB |
| ---: | ---: | ---: |
| 32,768 | 486,604,800 | 464.063 |
| 65,536 | 939,589,632 | 896.063 |
| 131,072 | 1,845,559,296 | 1,760.063 |
| 160,000 | 2,245,459,968 | 2,141.438 |
| 200,000 | 2,798,419,968 | 2,668.781 |
| 230,144 | 3,215,130,624 | 3,066.188 |
| 240,000 | 3,351,379,968 | 3,196.125 |
| 262,144 | 3,657,498,624 | 3,488.063 |

K and V must remain separate allocations. A combined 256-byte head-token record would waste 40 bytes for every head-token, 2,560 bytes per complete model-token, and exactly 671,088,640 bytes (640 MiB) at context 262,144.

## Other persistent state

- target recurrent/GDN live state: approximately 149.6 MiB;
- each full target rollback plane: approximately 149.6 MiB;
- MTP model block on GPU: approximately 194.9 MiB when active;
- Balanced MTP K2V2 draft cache: fixed at 256 tokens;
- prompt RAM cache: disabled (`--cache-ram 0`);
- Balanced target checkpoints: disabled in the single-slot qualified launcher;
- CUDA modules, graphs, allocator slack, compute arenas, and WDDM desktop allocations make the remainder.

Bounding MTP KV to 256 tokens saves 139,771,904 bytes (133.297 MiB) at 230,144 compared with a target-sized draft cache. This saving is required for resident MTP n=2 on the qualified 16 GB machine.

Extending the bounded-MTP target cache from 230,144 to 262,144 costs exactly 442,368,000 bytes (421.875 MiB). Because draft KV remains fixed at 256 tokens, this is the full-context speculative path on an effectively headless 5070 Ti. Display-attached WDDM residency can consume more than this margin and force shared-memory paging.

## Measured residency

The final literal 230K Balanced run reached 15,714 MiB total GPU use, with 15,075.672 MiB process-dedicated, 94 MiB process-shared/nonlocal, and 282 MiB minimum free. It completed without paging collapse.

A qualified target-only 262K allocation reported 572 MiB free at server load and 123 MiB after a complete 230K fill/decode. Desktop composition varies, so treat those values as measurements, not guarantees.

WDDM can report a small stable nonlocal allocation even for a resident workload. A growing nonlocal allocation accompanied by falling power/utilization and throughput is a paging failure.
