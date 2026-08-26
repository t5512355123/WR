# EXP-WRPC-STEP4-BUILD-INIT-ITERATOR-STATE-DIAGNOSTIC-20260826

## 實驗目的

依分支 2 建議，本輪只觀察 `build_init_readcmd()` 的第 2 次呼叫，不修改 parser、`CONFIG_INIT_COMMAND`、boot loop、PTP/SoftPLL/FSM、DMTD 或任何 Step 4 控制行為。觀察欄位為：

- `CALL_COUNT`
- `P_OFFSET_BEFORE`、`P_OFFSET_AFTER`（相對於 `shell_init_cmd` 的 offset，不輸出 raw pointer）
- `CURRENT_CHAR_BEFORE`
- `DELIMITER_SEEN`
- `CMD_LEN_RETURNED`
- `I_VALUE`
- `I_RESET_TRIGGERED`
- `END_OF_STRING_SEEN`

## 版本、編譯與燒錄

- iterator diagnostic code：`cc8c9c2`
- toolchain compatibility fix：`ae949c1`
- JTAG reader：`2817402`
- raw evidence：`d2ee2c3`
- Master/Slave firmware 與 Quartus image 均由 `ae949c1` 編譯
- Master build：成功，`timing_closed=NO`；worst setup slack `-0.389 ns`
- Slave build：成功，`timing_closed=NO`；worst setup slack `-0.412 ns`
- Master：`DE5 [1-11.1]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B1722A`
- Slave：`DE5 [1-11.2]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B05EEB`

pain 生成 config 與映像內字串皆核對為完整 init script：

```text
Master: vlan off;ptp stop;mode master;ptp start
Slave:  vlan off;ptp stop;mode slave;ptp start
```

完整原始輸出：

`raw/EXP-WRPC-STEP4-BUILD-INIT-ITERATOR-STATE-DIAG-20260826/iterator_state_diag_final.txt`

## 量測方法

燒錄完成後執行：

```text
quartus_stp -t scripts/jtag/read_boot_init_iterator_state_diag.tcl 12 1000
```

兩個 cable 各取 12 samples，間隔約 1 秒。reader 只透過 source probe 讀取 `PSTAT (0x00100A0C)`、`ASTAT (0x00100A14)` 與 `PTPSTAT (0x00100A10)`；Wishbone transaction 僅用於讀取，未要求 snapshot，也未改變 WR/SoftPLL 控制。

## 結果摘要

所有 12/12 samples 均穩定，`BEFORE_VALID=1`、`AFTER_VALID=1`、`TRACE_VALID=1`。

| Board | CALL_COUNT | P_OFFSET_BEFORE | CURRENT_CHAR_BEFORE | P_OFFSET_AFTER | CMD_LEN_RETURNED | I_VALUE | DELIMITER_SEEN | END_OF_STRING_SEEN | I_RESET_TRIGGERED |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | 2 | 39 | 0 (`NUL`) | 0 | 0 | 0 | 0 | 1 | 1 |
| Slave `DE5 [1-11.2]` | 2 | 9 | 112 (`p`) | 18 | 8 | 8 | 1 | 0 | 0 |

Master raw sample（12 次相同，PTPSTATE 的週期性低位可變）：

```text
PSTAT=0800009D ASTAT=3E000000 CALL_COUNT=2 P_OFFSET_BEFORE=39 P_OFFSET_AFTER=0 CMD_LEN_RETURNED=0 I_VALUE=0 CURRENT_CHAR_BEFORE=0 DELIMITER_SEEN=0 I_RESET_TRIGGERED=1 END_OF_STRING_SEEN=1 BEFORE_VALID=1 AFTER_VALID=1 TRACE_VALID=1
```

Slave raw sample（12 次 iterator 欄位相同）：

```text
PSTAT=08204825 ASTAT=39700800 CALL_COUNT=2 P_OFFSET_BEFORE=9 P_OFFSET_AFTER=18 CMD_LEN_RETURNED=8 I_VALUE=8 CURRENT_CHAR_BEFORE=112 DELIMITER_SEEN=1 I_RESET_TRIGGERED=0 END_OF_STRING_SEEN=0 BEFORE_VALID=1 AFTER_VALID=1 TRACE_VALID=1
```

## 判定

1. Master 的第 2 次 `build_init_readcmd()` 確實被呼叫並 return；進入時 `p` 已在 `shell_init_cmd` 的 offset 39，正好是完整 39-byte init string 的 NUL 結尾。
2. Master 第 2 次呼叫的行為是正常的 EOF 路徑：`CURRENT_CHAR_BEFORE=NUL`、`END_OF_STRING_SEEN=1`、`i=0`、`CMD_LEN_RETURNED=0`，接著觸發原有的 `p = shell_init_cmd` reset。這不是第 2 次掃描分隔符時回傳錯誤。
3. 在第 2 次呼叫入口已經位於 offset 39 的前提下，本輪直接把 boundary 固定為：第 1 條命令返回之後，iterator 已經落在整串字串結尾；boot loop 因 `cmd_len == 0` 結束。
4. 本輪只記錄第 2 次呼叫，因此不能單獨區分「第 1 次 fetch 未在分號切開」與「第 1 條命令執行期間將 iterator state 改到結尾」；但可以排除「第 2 次 `build_init_readcmd()` 在非 EOF 位置錯誤解析」這個較晚的假設。
5. Slave 同一套 reader 在 offset 9 的 `p` 看到分號並正常回傳 8 bytes，證明本輪診斷 encoding、讀取器與基本 iterator 路徑有效。

## Step 4 判定

`STEP4_ALLOWED=NO` 維持不變。本輪沒有進行 DMTD /2、threshold、reverse、SoftPLL/FSM 或 PTP functional behavior 的修改或解讀。

## 下一步邊界

等待分支 2 讀取本報告與 raw evidence 後提出下一個單一實驗；在收到新建議前不進行 parser 修正或 Step 4 功能修改。
