# EXP-WRPC-STEP4-BOOT-INIT-PER-COMMAND-STICKY-TRACE-20260826

## 實驗目的

上一輪 generic `shell_exec()` 診斷只能保存最後一次命令，無法分辨 boot script 的四條命令是否依序完成。本輪改在 `shell_boot_script()` 保存不可覆寫的 per-command before/after trace，並記錄每條命令的 return-code 類別與 `mode master` call/return。

本輪只增加 firmware diagnostic observability；不改變 `CONFIG_INIT_COMMAND`、PTP/SoftPLL/FSM/PI/DCO、endpoint/pfilter 或任何 WR control path。前一輪會覆寫歷史的 generic `shell_exec()` last-state 診斷也已移除。

## Trace encoding

診斷資料放在既有 `WDIAGS_PSTAT (0x00100A0C)` 的高位；原有 link/locked bits 0..1 保留。保存內容如下：

- command 1..4 各一個 `BEFORE` bit 與一個 `AFTER` bit
- `CMD1..CMD4_RC_CLASS`：`NOT_RUN=0`、`OK=1`、`POSITIVE=2`、`NEGATIVE=3`
- `MODE_MASTER_CALL_COUNT` 與 `MODE_MASTER_RETURN_COUNT`
- `SCRIPT_ENTER`、目前 command index、`TRACE_VALID`

預期的 built-in init command sequence 為：

1. `vlan off`
2. `ptp stop`
3. `mode master`（Master image）或 `mode slave`（Slave image）
4. `ptp start`

## Image、版本與燒錄

- firmware trace code commit：`b64b843`
- include 修正 commit：`39bb524`
- raw evidence commit：`9884ab6`
- Master Quartus build：成功，`timing_closed=NO`
- Slave Quartus build：成功，`timing_closed=NO`
- Master：`DE5 [1-11.1]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B1722A`
- Slave：`DE5 [1-11.2]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B05EEB`

## 量測方法

燒錄完成後，以 `scripts/jtag/read_boot_init_sticky_trace.tcl 12 1000` 對兩個 cable 各讀取 12 次，取樣間隔約 1 秒。reader 只讀取 `WDIAGS_PSTAT` 與 `WDIAGS_PTPSTAT`，不寫入 Wishbone register、不要求 snapshot，也不改變 WR/SoftPLL 控制。

完整原始輸出保存在：

`raw/EXP-WRPC-STEP4-BOOT-INIT-PER-COMMAND-STICKY-TRACE-20260826/boot_init_sticky_trace_final.txt`

## 結果摘要

| Board | Samples | SCRIPT_ENTER | CURRENT_INDEX | CMD1 | CMD2 | CMD3 | CMD4 | MODE_MASTER call/return |
|---|---:|---:|---:|---|---|---|---|---:|
| Master `DE5 [1-11.1]` | 12/12 | 1 | 1 | before=1, after=1, rc=OK | before=0, after=0, rc=NOT_RUN | before=0, after=0, rc=NOT_RUN | before=0, after=0, rc=NOT_RUN | 0 / 0 |
| Slave `DE5 [1-11.2]` | 12/12 | 1 | 4 | before=1, after=1, rc=OK | before=1, after=1, rc=OK | before=1, after=1, rc=OK | before=1, after=1, rc=OK | 0 / 0 |

代表性原始值：

- Master：`PSTAT=0x4C040045`，`PTPSTAT=0x00001104` 或 `0x00001106`
- Slave：`PSTAT=0x655403FD`，`PTPSTAT=0x00004109` 或 `0x00004106`

兩端均為 `TRACE_VALID=1`、`SCRIPT_ENTER=1`、link=1、locked=0；trace bit 在 12 次取樣中保持一致。Slave 的 `mode master` 計數為 0 是預期結果，因為 Slave init command 是 `mode slave`。

## 判定

1. Master 的第 1 條 `vlan off` 已留下 `BEFORE=1`、`AFTER=1`、`RC_CLASS=OK`。因此本輪直接證明 `shell_exec("vlan off")` 已返回成功；問題不再是 `cmd_vlan()` handler 內部不返回。
2. Master 沒有留下 command 2 的 `BEFORE`，也沒有進入 `ptp stop`、`mode master` 或 `ptp start`。目前可靠 boundary 是 command 1 的 after trace 之後、command 2 的 before trace 之前。
3. Slave 四條命令全部 before/after 完成且 return code 都為 OK，證明 sticky trace 的保存、讀取與完整 boot-script loop 在同一套 image 結構下可正常工作。
4. 這也解釋了先前「Master command index=1」與本輪「command 1 已 return」的差異：舊證據只顯示目前/最後 index，沒有保存 command 1 的返回歷史。
5. 目前仍未取得 Master 的 `mode master` call/return；`STEP4_ALLOWED=NO` 維持不變。

## 下一步邊界

下一輪只需把觀測點再縮到 command 1 return 後的 boot-script loop：區分 `shell_exec()` return 之後、`build_init_readcmd()` 前後，以及 command 2 before marker 寫入邊界。保持 init command string、DMTD/2、threshold、reverse、SoftPLL/FSM 與 Step 4 全部不變。
