# 歷史封存（舊 archive/ 路徑）

這是原 repository `archive/` 的歷史說明。歷史除錯原始碼目前保留在
`experiments/legacy/archive/diagnostics/`，不屬於 current build input，也不會
自動被當成新的 source template。Quartus database 與一般輸出資料夾未放入
原始碼封存；重整前備份的記載僅屬當時 provenance。

`MANIFEST.pain-source.sha256` retains the checksums recorded by the earlier
Pain-side archive inventory, with paths adjusted to this historical location.
That inventory also references 454 build/generated files that are not present
in this Laptop checkout, and 29 retained QSF files no longer match those
recorded hashes; it is provenance, not a complete integrity check of this
checkout. `MANIFEST.sha256` covers the exact regular files retained here
(excluding both manifests) and can be checked from repository root with
`sha256sum -c experiments/legacy/archive/MANIFEST.sha256`.

## 保留的歷史除錯版本

目前的純原始碼封存包含以下歷史實驗 tree。它們保留作為比較與 provenance，不會被正式 Quartus build 自動使用：

| Group | Archived trees |
|---|---|
| Clock/JTAG and board diagnostics | `clock625_jtagwb_diag`, `jtag_wb_diag`, `dac_diag` |
| DCO and Soft-PLL experiments | `dco_diag`, `dco_simplewa_diag`, `dco_simplewa_fix_diag`, `dco_simplewa_loadprobe_fwfix_diag`, `dco_simplewa_nosfp_diag`, `dco_simplewa_nosfp_loadprobe_diag`, `simplewa_diag` |
| RS422 and runtime diagnostics | `rs422_uart_diag`, `runtime_probe_diag`, `nosfpmatch_rs422_diag` |
| RX polarity and SFP diagnostics | `rxpol_diag`, `rxpol_both_diag`, `sfp_eeprom_diag`, `sfp_i2c_fix_diag` |
| Vendor diagnostic snapshot | `vendor/wrpc-sw_nosfpmatch_diag` |

舊 archive inventory 位於 `MANIFEST.pain-source.sha256`；目前 checkout 的
位元組級完整性清單為 `MANIFEST.sha256`。
