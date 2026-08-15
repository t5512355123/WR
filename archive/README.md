# Legacy Archive

Legacy diagnostic source is preserved under `archive/diagnostics/`. Quartus databases and ordinary output directories were excluded from the source archive because the pre-restructure backup retains the original tree. No legacy folder is deleted or treated as a new source template automatically.

`MANIFEST.sha256` lists the SHA256 of every archived file. The original full
trees and pre-restructure backups remain the authoritative fallback for any
generated database that was intentionally excluded from this source archive.

## Preserved legacy diagnostics

The source-only archive currently contains these legacy experiment trees. They
are retained for comparison and provenance; they are not automatically used by
the canonical Quartus build:

| Group | Archived trees |
|---|---|
| Clock/JTAG and board diagnostics | `clock625_jtagwb_diag`, `jtag_wb_diag`, `dac_diag` |
| DCO and Soft-PLL experiments | `dco_diag`, `dco_simplewa_diag`, `dco_simplewa_fix_diag`, `dco_simplewa_loadprobe_fwfix_diag`, `dco_simplewa_nosfp_diag`, `dco_simplewa_nosfp_loadprobe_diag`, `simplewa_diag` |
| RS422 and runtime diagnostics | `rs422_uart_diag`, `runtime_probe_diag`, `nosfpmatch_rs422_diag` |
| RX polarity and SFP diagnostics | `rxpol_diag`, `rxpol_both_diag`, `sfp_eeprom_diag`, `sfp_i2c_fix_diag` |
| Vendor diagnostic snapshot | `vendor/wrpc-sw_nosfpmatch_diag` |

The authoritative file-level inventory and hashes are in `MANIFEST.sha256`.
