# EXP-WRPC-STEP4-BOOT-LOOP-TRANSITION-DIAGNOSTIC-20260826

## 實驗目的

上一輪 per-command sticky trace 證明 Master 的第 1 條 `vlan off` 已成功 return，但沒有進入第 2 條 `ptp stop`。本輪只在 `shell_boot_script()` 的 command 1 → command 2 迴圈轉換加入 sticky checkpoint，以區分：

1. `shell_exec()` return 後是否仍能繼續執行
2. 是否進入下一次 `build_init_readcmd()`
3. 下一次命令取得是否回傳非空內容
4. command index 是否成功更新到 2
5. command 2 的 before marker 是否成功發布

本輪未修改 `CONFIG_INIT_COMMAND` 或任何 PTP/SoftPLL/FSM/PI/DCO、endpoint/pfilter、WR control 行為。

## Transition marker

marker 放在既有 `WDIAGS_ASTAT (0x00100A14)` 高位 bits 8..14；低 8 位 auxiliary state 保留：

| Bit | Marker |
|---:|---|
| 0 | `CMD1_AFTER_PUBLISHED` |
| 1 | `AFTER_SHELL_EXEC_RETURN` |
| 2 | `BEFORE_BUILD_INIT_READCMD`（針對 command 1 返回後的下一次 loop） |
| 3 | `AFTER_BUILD_INIT_READCMD` |
| 4 | `NEXT_COMMAND_PTR_VALID` |
| 5 | `NEXT_COMMAND_INDEX_SET` |
| 6 | `CMD2_BEFORE_PUBLISHED` |

## Image、版本與燒錄

- transition diagnostic code commit：`535f5da`
- raw evidence commit：`025b19a`
- Master build：成功，`timing_closed=NO`
- Slave build：成功，`timing_closed=NO`
- Master：`DE5 [1-11.1]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B1722A`
- Slave：`DE5 [1-11.2]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B05EEB`

此外，pain 上的生成 config 已核對為完整四條命令：

- Master：`vlan off;ptp stop;mode master;ptp start`
- Slave：`vlan off;ptp stop;mode slave;ptp start`

因此不是 `CONFIG_INIT_COMMAND` 在 build 時被截短。

## 量測方法

燒錄完成後，以 `scripts/jtag/read_boot_init_sticky_trace.tcl 12 1000` 對兩個 cable 各讀取 12 次，取樣間隔約 1 秒。reader 只讀取 `PSTAT`、`ASTAT` 與 `PTPSTAT`，不寫入 Wishbone register、不要求 snapshot，也不改變 WR/SoftPLL 控制。

完整原始輸出保存在：

`raw/EXP-WRPC-STEP4-BOOT-LOOP-TRANSITION-DIAG-20260826/boot_loop_transition_diag_final.txt`

## 結果摘要

| Board | Samples | `ASTAT` transition | CMD1 after | shell return | before readcmd | after readcmd | next ptr valid | next index set | CMD2 before published |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | 12/12 | `0x00000F00` | 1 | 1 | 1 | 1 | 0 | 0 | 0 |
| Slave `DE5 [1-11.2]` | 12/12 | `0x00007F00` | 1 | 1 | 1 | 1 | 1 | 1 | 1 |

Master 的 per-command sticky trace 同時保持：

```text
CMD1: BEFORE=1 AFTER=1 RC=OK
CMD2: BEFORE=0 AFTER=0 RC=NOT_RUN
CMD3: BEFORE=0 AFTER=0 RC=NOT_RUN
CMD4: BEFORE=0 AFTER=0 RC=NOT_RUN
CURRENT_INDEX=1
MODE_MASTER_CALL=0
MODE_MASTER_RETURN=0
```

Slave 則四條命令皆為 `BEFORE=1 / AFTER=1 / RC=OK`，`CURRENT_INDEX=4`。

## 判定

1. Master 的 `vlan off` 已完整返回，且 `CMD1_AFTER_PUBLISHED=1`；因此 `cmd_vlan()`/`shell_exec("vlan off")` 不再是目前 blocker。
2. Master 確實進入 command 1 返回後的下一次 loop：`AFTER_SHELL_EXEC_RETURN=1`、`BEFORE_BUILD_INIT_READCMD=1`、`AFTER_BUILD_INIT_READCMD=1`。
3. Master 沒有留下 `NEXT_COMMAND_PTR_VALID`。在已核對 init string 完整存在的前提下，表示第二次 `build_init_readcmd()` 對 command 2 回傳了 `cmd_len=0`，boot loop 因 `if (!cmd_len) break` 結束，沒有更新 command index，也沒有發布 command 2 before。
4. Slave 七個 marker 全部為 1，說明同一個 iterator 與 trace 設計在 Slave 能取得並完成後續命令；本輪結果不是 reader 或基本 sticky 保存失效。
5. 目前最精確的 firmware boundary 是：

```text
command 1 shell_exec return
  → command 1 after trace published
  → second build_init_readcmd() entered and returned
  → cmd_len == 0 / no next command accepted
  → command 2 not started
```

這輪尚不能單獨判定是 iterator pointer 被重設、pointer 被破壞、或 `build_init_readcmd()` 的 end-of-script 判斷異常；需要下一輪只針對 iterator state 做 source/runtime observability。

## Step 4 判定

`STEP4_ALLOWED=NO` 維持不變。DMTD /2、threshold、reverse、SoftPLL/FSM、PTP functional behavior 與 Step 4 均未更動，也未進行 Step 4 解讀。

## 下一步邊界

下一輪只保存 `build_init_readcmd()` 的 iterator state：在第二次呼叫前後記錄目前 `p` 相對於 `shell_init_cmd` 的位置、是否看到分隔符、回傳的 `cmd_len`，以及是否觸發 `i == 0` reset；不改 parser 或 boot command 行為。
