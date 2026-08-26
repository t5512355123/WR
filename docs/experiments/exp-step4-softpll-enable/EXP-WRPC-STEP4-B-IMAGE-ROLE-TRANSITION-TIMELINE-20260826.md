# EXP-WRPC-STEP4-B-IMAGE-ROLE-TRANSITION-TIMELINE-20260826

## 實驗身分

- 日期：2026-08-26
- Branch：`exp/step4-softpll-enable`
- B image functional commit：`73d16414cf015f9411431ae7f5a862afb8454098`
- Timeline script commit：`e2926dbd16875fb5e0927ebf6317c018e79c64f1`
- 實驗主機：`pain`
- 實驗類型：已燒錄 B image 的 read-only boot role/state transition timeline
- 本輪沒有 rebuild，沒有 RTL/firmware/SoftPLL 變更，沒有執行 Step 4

## 目的與執行方式

branch2 要求確認 B image 開機時是否會完成：

```text
default SLAVE
    -> CONFIG_INIT_COMMAND: mode master / mode slave
    -> stable runtime role/state
```

因此本輪只重新下載既有 B SOF 以觸發兩張板 boot，然後對每張板各做 100 筆、100 ms gap 的固定欄位讀取。每筆讀取的欄位相同：

```text
CPU_RESET_N / boot marker
endpoint MAC
WDIAGS mode
PTP/PPSI state
PTP RX/TX counters
FOREIGN / best / detection / WR config
parent flags
LOCK_ENABLE
PSTAT
```

timeline script 只送 Wishbone read，不寫 control register、不寫 DATA_SNAPSHOT、不新增 RTL counter。實際第一筆 sample 約在 probe setup 後 57–58 ms，最後一筆約在 16.14–16.15 s；每張板均在 program command 完成後立即啟動對應 timeline。

## Program restart provenance

本輪重新使用上一輪已驗證的同一份 SOF，沒有重新編譯：

| Image | SOF / cable | Checksum | Result |
|---|---|---|---|
| Master B | `output_files_master_jtag/DE5a_wr_master_jtag.sof` → `DE5 [1-11.1]` | `0x30B1722A` | configuration succeeded; 0 errors, 0 warnings |
| Slave B | `output_files_slave_jtag/DE5a_wr_slave_jtag.sof` → `DE5 [1-11.2]` | `0x30B05EEB` | configuration succeeded; 0 errors, 0 warnings |

## Master timeline

| 指標 | 結果 |
|---|---|
| samples / duration | 100 / 16.143 s |
| CPU_RESET_N | 100/100 = 1 |
| boot marker | 100/100 = `0x0000B004` |
| MAC | `02:00:22:33:44:01` 97/100；3 筆為 torn read 變體 |
| WDIAGS mode | `3 SLAVE` 100/100；沒有 `2 MASTER` |
| PTP state | `4 LISTENING` 88/100；`6 MASTER` 12/100 |
| FOREIGN | 0:44、1:55、3:1；沒有穩定 parent record |
| parent flags | `PARENT_IS_WR=0`, `PARENT_MODE_ON=0`, `PARENT_CAL=0` 100/100 |
| LOCK_ENABLE | `0x00000000` 100/100 |

Master 從第一筆到最後一筆都沒有出現 `MODE=2 MASTER`。中段雖曾出現 PTP state `6 MASTER`，但 WDIAGS mode 仍為 `3 SLAVE`；這不是完整的 Slave→Master role transition，而是 mode/state telemetry mismatch。boot marker `0xB004` 表示 firmware 已走到既有 `wrc_tasks_run_inits()` 後的 marker，不能據此證明 `mode master` shell command 已成功執行。

## Slave timeline

| 指標 | 結果 |
|---|---|
| samples / duration | 100 / 16.149 s |
| CPU_RESET_N | 100/100 = 1 |
| boot marker | 100/100 = `0x0000B004` |
| MAC | `02:00:22:33:44:02` 100/100 |
| WDIAGS mode | `3 SLAVE` 100/100；沒有 `2 MASTER` |
| PTP state | `4 LISTENING` 26/100；`9 SLAVE` 68/100；`6 MASTER` 6/100 |
| FOREIGN | `1` 100/100；best index 0 74/100、255 26/100 |
| parent flags | `PARENT_IS_WR=0`, `PARENT_MODE_ON=0`, `PARENT_CAL=0` 100/100 |
| LOCK_ENABLE | `0x00000000` 100/100 |

Slave 最終狀態大多為 PTP state `9 SLAVE`，但 parent flags 和 LOCK_ENABLE 沒有形成穩定的既有 Step 3 evidence；同樣沒有讀到任何 `MODE=2 MASTER`。這符合 role mode 維持 Slave，但不能單靠這輪把所有 Step 2/3 mailbox failure 歸因於 firmware role。

## 判定

```text
MASTER_MODE_TRANSITION = NOT_OBSERVED
MASTER_STABLE_MODE     = SLAVE (100/100)
MASTER_PTP_STATE       = LISTENING 88/100, MASTER 12/100
SLAVE_MODE             = SLAVE (100/100)
MAC_IDENTITY           = CORRECT on both boards (Master 97/100 clean; Slave 100/100)
BOOT_MARKER            = B004 on both boards
STEP2/3                = NOT RERUN in this timeline-only step
STEP4_ALLOWED          = NO
```

這輪不支持「Step 2/3 只是執行太早」的解釋：在約 16 秒觀測窗口中，Master 仍沒有 `MODE=2 MASTER`。最精確的目前 blocker 是：

```text
Master role mode does not transition to MASTER,
while PTP state can transiently report MASTER.
```

因此下一步應交由 branch2 決定是否進一步追 `CONFIG_INIT_COMMAND` 的執行路徑、shell boot task scheduling 或 mode/state telemetry consistency；本輪不自行修改 firmware，也不重新跑 Step 2/3 或 Step 4。

## Raw evidence

完整原始檔位於：

`raw/EXP-WRPC-STEP4-B-IMAGE-ROLE-TRANSITION-TIMELINE-20260826/`

| 檔案 | SHA256 |
|---|---|
| `boot_role_master_program.log` | `15126b4c59871268765f321a370c6237d97c593f0f05f95d9842b789c52e2375` |
| `boot_role_master_timeline.log` | `96b964b4311ec0af558797e9e355c587fcdb0421d1fc624e84ccb3af22060111` |
| `boot_role_slave_program.log` | `b4ee008b8e11c1c34c0964061acce0a705410618842b67b038dc4883d6d677ee` |
| `boot_role_slave_timeline.log` | `042c826ca4ac3e9b422b5fed0615ee0157d090f320edbbfa3a7ff753d566237b` |

以上 raw log 與本報告同一 commit 提交；timeline script 為 `scripts/jtag/read_boot_role_timeline.tcl`。
