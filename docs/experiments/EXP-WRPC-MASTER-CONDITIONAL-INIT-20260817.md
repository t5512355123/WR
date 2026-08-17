# 實驗紀錄：依映像選擇初始 PTP 角色

## 實驗基本資料

- Experiment ID：`EXP-WRPC-MASTER-CONDITIONAL-INIT-20260817`
- 日期：2026-08-17
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`70b3c4c`（依映像角色選擇初始PTP模式）
- 穩定基線：`main @ 0494976`
- Quartus：Quartus Prime 17.0.0 Build 595 SJ Standard Edition
- 硬體：DE5a Master 使用 JTAG cable `DE5 [1-11.1]`；Slave 使用 `DE5 [1-11.2]`

## 想驗證什麼

驗證 White Rabbit firmware 是否能在 `wrc_initialize()` 階段，依 Master/Slave 映像選擇正確的初始 PTP 角色：

- Master 映像應直接進入 `WRC_MODE_MASTER`（數值 2）。
- Slave 映像應維持 `WRC_MODE_SLAVE`（數值 3）。
- 不應再透過 shell 初始化階段直接呼叫角色 API。

這是針對前一版 Master 在 `B002` 早期初始化停住的最小修正實驗；沒有修改 PHY、PTP 演算法、servo、DMTD、SI5341 或硬體拓撲。

## 相較前一版唯一修改

1. `vendor/wrpc-sw/shell/shell.c`
   - 移除上一版新增的 `wrpc.h` include。
   - 移除 `shell_boot_script()` 中直接呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()` 的區塊。
   - 恢復既有 built-in/flash 初始化命令流程。
2. `vendor/wrpc-sw/wrc_main.c`
   - 以既有 `CONFIG_FORCE_MASTER_AFTER_INIT` 宏選擇初始角色：Master 映像呼叫 `WRC_MODE_MASTER`，其他映像呼叫 `WRC_MODE_SLAVE`。

## Firmware 與硬體產物

### MIF

```text
Master MIF: build/firmware/master/wrc.mif
SHA-256: 6ccf3328f7ff63630227e24c3c70c449ebb6ebae7c17d161331568b56e2fa754

Slave MIF: build/firmware/slave/wrc.mif
SHA-256: 6f9a0503cbd789282c2ea03f02007fa0fd18b9a414999dd335169f261647bc46
```

### SOF 與 Quartus compile

```text
Master SOF: quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof
SHA-256: e42da0a643bac075547313cbba43280d26ebe60d0694a7b08253ef83775121a7
Compile: Full Compilation successful, 0 errors, 272 warnings

Slave SOF: quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
SHA-256: 0aeab4bb3e08855742949ef81c373965abd9ef03ca2963a0d76b00acce3893ee
Compile: Full Compilation successful, 0 errors, 274 warnings
```

### 燒錄結果

- Slave Programmer：成功，checksum `0x30A152A4`，JTAG ID `0x02E660DD`，0 errors/0 warnings。
- Master Programmer：成功，checksum `0x30A31DBA`，JTAG ID `0x02E660DD`，0 errors/0 warnings。
- 原始 Programmer log：
  - `artifacts/EXP-WRPC-MASTER-CONDITIONAL-INIT-20260817/program_slave.log`
  - `artifacts/EXP-WRPC-MASTER-CONDITIONAL-INIT-20260817/program_master.log`

## JTAG/runtime 原始結果摘要

讀取工具：`scripts/jtag/read_wb_runtime.tcl`。同一輪讀取 Master `DE5 [1-11.1]` 與 Slave `DE5 [1-11.2]`，時間點為燒錄後約 0、1、5、10、25 秒。完整原始輸出保存於：

`artifacts/EXP-WRPC-MASTER-CONDITIONAL-INIT-20260817/runtime_readings.log`

### Master

```text
t=0s : cpu_marker=B00B, fault=0, reset=0, WDIAGS_MODE=0, PTP=0, PTP_RX=0, PTP_TX=0
t=1s : cpu_marker=B00B, fault=0, reset=0, WDIAGS_MODE=0, PTP=0, PTP_RX=0, PTP_TX=0
t=5s : cpu_marker=B00B, fault=0, reset=0, WDIAGS_MODE=0, PTP=0, PTP_RX=0, PTP_TX=0
t=10s: cpu_marker 未看到，reset=1，WDIAGS_MODE=0，PTP=0
t=25s: cpu_marker=B00B, fault=0, reset=0, WDIAGS_MODE=0, PTP=0, PTP_RX=0, PTP_TX=0
```

### Slave

```text
t=0s : cpu_marker=B004, fault=0, reset=0, WDIAGS_MODE=3, PTP_RX=0, PTP_TX=3
t=1s : cpu_marker=B004, fault=0, reset=0, WDIAGS_MODE=3, PTP_RX=0, PTP_TX=4
t=5s : cpu_marker=B004, fault=0, reset=0, WDIAGS_MODE=3, PTP_RX=0, PTP_TX=4
t=10s: cpu_marker=B004, fault=0, reset=0, WDIAGS_MODE=3, PTP_RX=0, PTP_TX=4
t=25s: cpu_marker=B004, fault=0, reset=0, WDIAGS_MODE=3, PTP_RX=0, PTP_TX=4
```

另外，Slave 的 `WDIAGS_SSTAT=0`、`WDIAGS_PSTAT=0`、`WDIAGS_UCNT=0`；本輪沒有看到 Slave parent/servo/SoftPLL lock 或 `time_valid=1`、`pps_valid=1` 的證據。Master 也沒有進入 `WDIAGS_MODE=2`。

## Observation

1. Quartus 編譯與兩片 FPGA 燒錄都成功，SOF checksum 與 JTAG ID 均可追溯。
2. Slave 能到達 `B004` 且維持 `WDIAGS_MODE=3`，但沒有收到 PTP（`PTP_RX=0`），因此沒有形成 parent/servo 活動證據。
3. Master 沒有到達預期的 `WDIAGS_MODE=2`，且 `PTP_TX=0`；10 秒讀值出現短暫 reset 狀態，表示本輪 Master runtime 不穩定或診斷讀取時剛好遇到 reset/重啟狀態。
4. 因此「只用既有宏在 `wrc_initialize()` 選 Master」在目前映像上尚未證明可行。

## Conclusion

本實驗**失敗，且不能宣稱兩片 DE5a 已同步**。目前證據只支持：兩份 SOF 都能配置成功，Slave firmware 可運作到 `B004`；但 Master 沒有進入 Master role，Slave 沒有看到 PTP RX 或 servo/SoftPLL 活動。根因尚未由本實驗確定，不能直接歸因於 PHY、SoftPLL 或 time-valid gating。

## Next Step

1. 保留本輪 SOF、MIF 與原始 runtime log，不覆蓋作為後續比較基準。
2. 將本輪結果交叉檢查 `wrc_initialize()` 的執行順序、`CONFIG_FORCE_MASTER_AFTER_INIT` 的實際編譯定義，以及 Master MIF 是否確實包含預期的 `WRC_MODE_MASTER` 路徑。
3. 下一輪仍只允許一個變因；在確認 firmware image/layout 與 JTAG 讀值一致前，不修改 PHY、光路、pre-emphasis 或 servo 參數。
