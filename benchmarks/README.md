# Public benchmark harness

Start the desired launcher in one terminal, then run a benchmark in another. The server must have enough allocated context for the requested live depth.

```powershell
python .\benchmarks\run-depth-curve.py --profile mtp --depths 2048 8192 16000 32000
python .\benchmarks\run-long-binding.py --profile balanced --depth 230000
python .\benchmarks\run-normal-generation.py --profile mtp --depths 2048 8192 32000
```

For the 12-case 32K firewall, capture target-only tokens, then require an MTP or DFlash run to match every generated token:

```powershell
python .\benchmarks\run-firewall.py --profile target --output target-firewall.json
python .\benchmarks\run-firewall.py --profile mtp --reference target-firewall.json
```

To verify hybrid/KVarN state persistence, start a launcher with a writable slot directory and run the save/reload identity gate:

```powershell
.\launchers\run-mtp-short.ps1 -SlotSavePath .\benchmarks\results\slot-state
python .\benchmarks\run-save-reload.py --profile mtp
```

For rollover identity, first start a target-only server and capture a reference, stop it, start the MTP server, then compare:

```powershell
.\launchers\run-max-context-262k.ps1 -Context 1152
python .\benchmarks\run-rollover.py --profile target --tokens 924 --output target-rollover.json
.\launchers\run-mtp-short.ps1 -Context 1152
python .\benchmarks\run-rollover.py --profile mtp --tokens 924 --reference target-rollover.json
```

Stop the first server before starting the second. The frozen fixture uses a 100-token prompt, 924 generated tokens, and a 1,152-token server context so it crosses the bounded 256-token MTP cache three times while leaving one complete 128-token KVarN body of headroom.

Large result directories should be placed on a data drive with `--output` rather than committed.
