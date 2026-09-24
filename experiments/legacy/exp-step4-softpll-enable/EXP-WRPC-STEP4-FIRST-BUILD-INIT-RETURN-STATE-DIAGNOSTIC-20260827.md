# EXP-WRPC-STEP4-FIRST-BUILD-INIT-RETURN-STATE-DIAGNOSTIC-20260827

## 實驗目的

依分支 2 針對 `4ac38e1` 的建議，本輪只保存第一次 `build_init_readcmd()` 呼叫的 return state，並讓這筆資料在後續呼叫中保持 sticky。沒有修改 parser、`CONFIG_INIT_COMMAND`、boot command 行為、PTP/SoftPLL/FSM、DMTD 或任何 Step 4 控制。

## 版本、編譯與燒錄

- first-call sticky diagnostic code：`4d9aaca`
- raw evidence：`2c0c2cc`
- Master/Slave firmware 與 Quartus image 均由 `4d9aaca` 編譯
- Master build：成功，`timing_closed=NO`；worst setup slack `-0.389 ns`
- Slave build：成功，`timing_closed=NO`；worst setup slack `-0.412 ns`
- Master：`DE5 [1-11.1]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B1722A`
- Slave：`DE5 [1-11.2]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B05EEB`

編譯後的 init string 仍為：

```text
Master: vlan off;ptp stop;mode master;ptp start
Slave:  vlan off;ptp stop;mode slave;ptp start
```

## 量測方法

燒錄完成後執行：

```text
quartus_stp -t scripts/jtag/read_boot_init_first_iterator_state_diag.tcl 12 1000
```

兩個 cable 各取 12 samples，間隔約 1 秒。reader 觀察 `PSTAT`、`ASTAT` 與 `PTPSTAT`；Wishbone transaction 僅用於讀取，未要求 snapshot，也未改變 WR/SoftPLL 控制。`CALL1_RETURN_P_OFFSET_STICKY` 由 firmware 只在 call 1 寫入，後續 `build_init_readcmd()` 呼叫不會覆寫。

完整原始輸出：

`raw/EXP-WRPC-STEP4-FIRST-BUILD-INIT-RETURN-STATE-DIAG-20260827/first_iterator_state_diag_final.txt`

## 結果摘要

所有 12/12 samples 均穩定，`CALL1_COUNT=1`、`CALL1_BEFORE_VALID=1`、`CALL1_AFTER_VALID=1`、`TRACE_VALID=1`。

| Board | CALL1_P_OFFSET_BEFORE | CALL1_RETURN_P_OFFSET_STICKY | CALL1_CMD_LEN | CALL1_I_VALUE | CALL1_CURRENT_CHAR_AFTER | DELIMITER_SEEN | END_OF_STRING_SEEN | RESET_TRIGGERED |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | 30 | 39 | 9 | 9 | 0 (`NUL`) | 0 | 1 | 0 |
| Slave `DE5 [1-11.2]` | 0 | 9 | 8 | 8 | 112 (`p`) | 1 | 0 | 0 |

offset 對照如下：

```text
0..7   vlan off
8      ;
9..16  ptp stop
17     ;
18..28 mode master/slave
29     ;
30..38 ptp start
39     NUL
```

Master 穩定樣本：

```text
PSTAT=04249C79 ASTAT=3C000900 CALL1_COUNT=1 CALL1_P_OFFSET_BEFORE=30 CALL1_RETURN_P_OFFSET_STICKY=39 CALL1_CMD_LEN=9 CALL1_I_VALUE=9 CALL1_CURRENT_CHAR_AFTER=0 CALL1_DELIMITER_SEEN=0 CALL1_RESET_TRIGGERED=0 CALL1_END_OF_STRING_SEEN=1 CALL1_BEFORE_VALID=1 CALL1_AFTER_VALID=1 TRACE_VALID=1
```

Slave 穩定樣本：

```text
PSTAT=04202401 ASTAT=39700800 CALL1_COUNT=1 CALL1_P_OFFSET_BEFORE=0 CALL1_RETURN_P_OFFSET_STICKY=9 CALL1_CMD_LEN=8 CALL1_I_VALUE=8 CALL1_CURRENT_CHAR_AFTER=112 CALL1_DELIMITER_SEEN=1 CALL1_RESET_TRIGGERED=0 CALL1_END_OF_STRING_SEEN=0 CALL1_BEFORE_VALID=1 CALL1_AFTER_VALID=1 TRACE_VALID=1
```

## 判定

1. Master 在本輪 `shell_boot_script()` 的第一次被觀察到的 `build_init_readcmd()` 呼叫，入口 `p` 已經位於 offset 30，也就是第四條 `ptp start` 的起點；它讀取 9 bytes 到 offset 39，看到 NUL，沒有看到分號，也沒有在這次呼叫觸發 `i == 0` reset。
2. 因此，前一輪第二次呼叫看到的 offset 39/EOF 並不是第二次 parser 自己把正常的 `ptp stop` 解析成空字串；在第一次被觀察的 call 之前，iterator 已經不在 offset 0，而在最後一條命令的起點。
3. Slave 的第一次呼叫為 offset 0→9、長度 8、看到分號，證明同一份 first-call sticky encoding 能正確捕捉正常的第一條命令。
4. 本輪仍不能單獨判定 offset 30 是由哪一次更早的 `build_init_readcmd()` 呼叫造成；最合理的邊界是 function-static iterator `p` 在 `shell_boot_script()` 開始前已經保留了跨呼叫狀態，或在較早的呼叫中被推進到 offset 30。這正是下一步應該檢查的 state lifetime，而不是修改 parser 分隔符邏輯。

## Step 4 判定

`STEP4_ALLOWED=NO` 維持不變。本輪沒有進行 DMTD /2、threshold、reverse、SoftPLL/FSM 或 PTP functional behavior 的修改或解讀。

## 下一步邊界

等待分支 2 讀取本報告與 raw evidence 後提出下一個單一實驗；在收到新建議前不進行 parser 修正或 Step 4 功能修改。
