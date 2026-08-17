# 實驗紀錄：使用內建 `ptp master` 命令切換 Master 角色

## 實驗基本資料

- Experiment ID：`EXP-WRPC-MASTER-PTP-MASTER-COMMAND-20260817`
- 日期：2026-08-17
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`7374ce4`（恢復穩定初始化並使用ptp master命令）
- 參考穩定基線：`b4c93bf`
- Quartus：Quartus Prime 17.0.0 Build 595 SJ Standard Edition
- 硬體：Master `DE5 [1-11.1]`；Slave `DE5 [1-11.2]`

## 想驗證什麼

先恢復已知能完成早期初始化的 `wrc_initialize()` 固定 Slave 路徑，再透過 Master image 的 built-in init command 使用原始碼已註冊的 `ptp master` 子命令，驗證 Master 是否能在 shell 初始化階段切換到 `WRC_MODE_MASTER=2`，並讓 Slave 收到正常的 PTP 流量。

## 相較穩定基線的唯一研究變因

- `vendor/wrpc-sw/wrc_main.c` 恢復固定呼叫 `wrc_ptp_set_mode(WRC_MODE_SLAVE)`，不在早期初始化選擇 Master。
- `firmware/configs/de5a_master_defconfig` 的命令由：

  ```text
  vlan off;ptp stop;mode master;ptp start
  ```

  改為：

  ```text
  vlan off;ptp stop;ptp master;ptp start
  ```

`cmd_ptp.c` 明確註冊 `master` 子命令；本輪沒有修改 PHY、PTP 演算法、servo、DMTD、SI5341 或硬體拓撲。

## Firmware 與硬體產物

### MIF

```text
Master MIF: build/firmware/master/wrc.mif
SHA-256: 2ff285f34fd796f2140c28bce5b494e0373025b963c26199a1cd58121e0e06a7

Slave MIF: build/firmware/slave/wrc.mif
SHA-256: 4fdcc806374ef330d3f5c4cf132969eae34e6aa021211b7c9705cc8e39b743df
```

Master ELF 以 `strings` 核對到：

```text
vlan off;ptp stop;ptp master;ptp start
```

### SOF 與 Quartus compile

```text
Master SOF: quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof
SHA-256: a20aefc533e6585eb2bd21c39734d17413375c4d0f4134e3144bae118982e71b
Compile: Full Compilation successful, 0 errors, 272 warnings

Slave SOF: quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
SHA-256: 5093a297cd2b8f666b019d701350df4522a27a301ede089c70ce7fd09ce28326
Compile: Full Compilation successful, 0 errors, 274 warnings
```

### 燒錄結果

- Slave：成功，checksum `0x30A152A4`，JTAG ID `0x02E660DD`，0 errors/0 warnings。
- Master：成功，checksum `0x30A31DBA`，JTAG ID `0x02E660DD`，0 errors/0 warnings。
- 原始 Programmer log：
  - `artifacts/EXP-WRPC-MASTER-PTP-MASTER-COMMAND-20260817/program_slave.log`
  - `artifacts/EXP-WRPC-MASTER-PTP-MASTER-COMMAND-20260817/program_master.log`

## JTAG/runtime 原始結果

讀取工具：`scripts/jtag/read_wb_runtime.tcl`。同一輪讀取燒錄後約 0、10、25、60 秒；完整輸出保存於：

`artifacts/EXP-WRPC-MASTER-PTP-MASTER-COMMAND-20260817/runtime_readings.log`

### Master `DE5 [1-11.1]`

```text
t=0s : marker=B004, fault=0, reset=0, MODE=3, SSTAT=0, PSTAT=1, PTP_RX=0x00000005, PTP_TX=0x00000003
t=10s: marker=B004, fault=0, reset=0, MODE=3, SSTAT=0, PSTAT=1, PTP_RX=0x00000018, PTP_TX=0x00000009
t=25s: marker=B004, fault=0, reset=0, MODE=3, SSTAT=0, PSTAT=1, PTP_RX=0x0000002F, PTP_TX=0x00000016
t=60s: marker=B004, fault=0, reset=0, MODE=3, SSTAT=0, PSTAT=1, PTP_RX=0x00000053, PTP_TX=0x00000033
```

### Slave `DE5 [1-11.2]`

```text
t=0s : marker=B004, fault=0, reset=0, MODE=3, SSTAT=0, PSTAT=1, PTP_RX=0x00000003, PTP_TX=0x00000008
t=10s: marker=B004, fault=0, reset=0, MODE=3, SSTAT=1, PSTAT=1, PTP_RX=0x00000009, PTP_TX=0x0000001E
t=25s: marker=B004, fault=0, reset=0, MODE=3, SSTAT=1, PSTAT=1, PTP_RX=0x00000016, PTP_TX=0x00000035
t=60s: marker=B004, fault=0, reset=0, MODE=3, SSTAT=1, PSTAT=1, PTP_RX=0x00000033, PTP_TX=0x00000056
```

其他重要 raw 值：60 秒時 Slave `FOREIGN_META=0x00000001`、`DMS_L=0x0008A16B`、`CKO=0x094B7681`；但 `SETP=0`、`UCNT=0`，且本輪沒有讀到可宣稱 `time_valid=1`、`pps_valid=1` 的完整證據。

## Observation

1. 本輪兩片都穩定完成初始化，`cpu_marker=B004`、CPU fault=0，沒有重現前一輪 Master 的 `B002/reset` 早期異常。
2. 兩片的 PTP RX/TX 計數都持續增加，表示 PTP packet path 已經有活動。
3. Master 在完整 60 秒內仍保持 `WDIAGS_MODE=3`，沒有進入預期的 `MODE=2`；因此 `ptp master` 命令沒有在本輪達成角色切換，或其切換條件未完成。
4. Slave 在 10 秒後 `SSTAT` 從 0 變 1，且有 foreign/offset 相關 raw 值，但這尚不足以等同 SoftPLL lock 或時間有效。

## Conclusion

本實驗**編譯與燒錄成功，runtime 初始化與 PTP 封包活動成功，但 Master role 驗證失敗，不能宣稱兩片已同步**。證據支持「早期 firmware 初始化已恢復、雙向 PTP packet path 有活動」；不支持「Master 已切到 mode2」或「Slave 已完成 WR time synchronization」。目前根因仍需釐清，不能僅依 `PSTAT=1`、foreign record 或非零 offset 欄位宣稱鎖定。

## Next Step

1. 保留本輪 MIF、SOF、Programmer 與 60 秒 runtime log 作為新 baseline。
2. 唯讀核對 `shell_boot_script()` 是否實際執行每一段 `CONFIG_INIT_COMMAND`，以及 `wrc_ptp_set_mode(MASTER)` 的返回值；必要時加一個不改角色的 command-stage marker，避免再用 mode3 推測命令是否執行。
3. 在看到 Master `MODE=2` 且持續送出 PTP 後，才繼續追 Slave `SSTAT/PSTAT/UCNT/CKO/SETP`、`time_valid` 與 `pps_valid`；目前不改 PHY 或光路參數。
