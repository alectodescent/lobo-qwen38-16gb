# Frozen reference summary

This is the compact, sanitized reference carried into the first public release. It contains no raw private paths or prompt data.

- Runtime source snapshot: `84ee2d114ace12dce6b0b2e16aae03d5cd4d2298`
- GSQ base: `64b53b64c7aa39f20a7e54bd80582fe595b1d745624ee8a72e92508c0326d810`
- MTP pack: `4eb8482539194ed9bc1555c88613f39f2e65db37b16d9ab173f908e78d454512`
- Balanced literal long-binding: exact, 186.7059 prompt tok/s, 36.2569 committed tok/s, resident
- Rollover: 924/924 target-identical tokens, three 256-token draft-window crossings, 90.1129 versus 47.9722 tok/s
- Backend IQ matrix: 98/98 passed
- KVarN parity, state save/reload, and transactional copy: passed

See `frozen-reference.json` for the structured curve and memory fields. Absolute rates from different fixtures are not directly comparable.

