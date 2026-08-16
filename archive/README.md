# 歷史封存

歷史除錯原始碼保留在 `archive/diagnostics/`。Quartus database 與一般輸出資料夾未放入原始碼封存，因為重整前備份仍保留完整 tree。沒有任何歷史資料夾被刪除，也不會自動被當成新的 source template。

`MANIFEST.sha256` 列出每個封存檔案的 SHA256。對於刻意排除的 generated database，原始完整 tree 與重整前備份仍是正式的 fallback 來源。

## 保留的歷史除錯版本

目前的純原始碼封存包含以下歷史實驗 tree。它們保留作為比較與 provenance，不會被正式 Quartus build 自動使用：

| Group | Archived trees |
|---|---|
| Clock/JTAG and board diagnostics | `clock625_jtagwb_diag`, `jtag_wb_diag`, `dac_diag` |
| DCO and Soft-PLL experiments | `dco_diag`, `dco_simplewa_diag`, `dco_simplewa_fix_diag`, `dco_simplewa_loadprobe_fwfix_diag`, `dco_simplewa_nosfp_diag`, `dco_simplewa_nosfp_loadprobe_diag`, `simplewa_diag` |
| RS422 and runtime diagnostics | `rs422_uart_diag`, `runtime_probe_diag`, `nosfpmatch_rs422_diag` |
| RX polarity and SFP diagnostics | `rxpol_diag`, `rxpol_both_diag`, `sfp_eeprom_diag`, `sfp_i2c_fix_diag` |
| Vendor diagnostic snapshot | `vendor/wrpc-sw_nosfpmatch_diag` |

正式的檔案層級 inventory 與 hash 位於 `MANIFEST.sha256`。
