# EXP-WRPC-STEP4-STATIC-P-PREBOOT-CALLER-AUDIT-20260827

## 實驗目的

依分支 2 對 `e1f277e` 的建議，本輪只追蹤 `build_init_readcmd()` 的 function-static iterator `p` 是否在 `shell_boot_script()` 前已被其他 caller 消耗。加入不在 `shell_boot_script()` entry reset 的 global call counter，並以 caller ID 標記 `BOOT_SCRIPT`、`SHOW_BUILD_INIT`、`OTHER`；沒有加入 `p` reset，也沒有修改 parser、init string、PTP/SoftPLL/FSM、DMTD 或 Step 4 控制。

## 版本、編譯與燒錄

- static-p preboot caller diagnostic code：`233903e`
- raw evidence：`72e0ad3`
- Master/Slave firmware 與 Quartus image 均由 `233903e` 編譯
- Master build：成功，`timing_closed=NO`；worst setup slack `-0.389 ns`
- Slave build：成功，`timing_closed=NO`；worst setup slack `-0.412 ns`
- Master：`DE5 [1-11.1]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B1722A`
- Slave：`DE5 [1-11.2]`，program 成功，0 errors/0 warnings，SOF checksum `0x30B05EEB`

兩個映像的完整 init string 仍為：

```text
Master: vlan off;ptp stop;mode master;ptp start
Slave:  vlan off;ptp stop;mode slave;ptp start
```

## 量測方法

燒錄完成後執行：

```text
quartus_stp -t scripts/jtag/read_boot_init_static_p_preboot_caller_audit.tcl 12 1000
```

兩個 cable 各取 12 samples，間隔約 1 秒。global call counter 從 firmware 啟動後累計，`shell_boot_script()` entry 不會清零；entry 時先 snapshot preboot count 與最後 caller，再保存第一次 boot-script call 的 `p` state。reader 只讀取 `PSTAT`、`ASTAT` 與 `PTPSTAT`。

完整原始輸出：

`raw/EXP-WRPC-STEP4-STATIC-P-PREBOOT-CALLER-AUDIT-20260827/static_p_preboot_caller_audit_final.txt`

## 結果摘要

所有 12/12 samples 均穩定，`CALL1_BEFORE_VALID=1`、`CALL1_AFTER_VALID=1`、`TRACE_VALID=1`。

| Board | GLOBAL_BUILD_INIT_CALL_COUNT | PREBOOT_LAST_CALLER | CALL1_P_OFFSET_BEFORE | CALL1_RETURN_P_OFFSET_STICKY | CALL1_CMD_LEN | CALL1_I_VALUE | CALL1_CURRENT_CHAR_AFTER | DELIMITER_SEEN | END_OF_STRING_SEEN | RESET_TRIGGERED |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | 1 | `NONE` | 30 | 39 | 9 | 9 | 0 (`NUL`) | 0 | 1 | 0 |
| Slave `DE5 [1-11.2]` | 1 | `NONE` | 0 | 9 | 8 | 8 | 112 (`p`) | 1 | 0 | 0 |

Master 穩定樣本：

```text
PSTAT=04249C79 ASTAT=3C000900 PTPSTAT=00001104 GLOBAL_BUILD_INIT_CALL_COUNT=1 PREBOOT_LAST_CALLER_ID=0 PREBOOT_LAST_CALLER=NONE CALL1_P_OFFSET_BEFORE=30 CALL1_RETURN_P_OFFSET_STICKY=39 CALL1_CMD_LEN=9 CALL1_I_VALUE=9 CALL1_CURRENT_CHAR_AFTER=0 CALL1_DELIMITER_SEEN=0 CALL1_RESET_TRIGGERED=0 CALL1_END_OF_STRING_SEEN=1 CALL1_BEFORE_VALID=1 CALL1_AFTER_VALID=1 TRACE_VALID=1
```

Slave 穩定樣本：

```text
PSTAT=04202401 ASTAT=39700800 PTPSTAT=00004109 GLOBAL_BUILD_INIT_CALL_COUNT=1 PREBOOT_LAST_CALLER_ID=0 PREBOOT_LAST_CALLER=NONE CALL1_P_OFFSET_BEFORE=0 CALL1_RETURN_P_OFFSET_STICKY=9 CALL1_CMD_LEN=8 CALL1_I_VALUE=8 CALL1_CURRENT_CHAR_AFTER=112 CALL1_DELIMITER_SEEN=1 CALL1_RESET_TRIGGERED=0 CALL1_END_OF_STRING_SEEN=0 CALL1_BEFORE_VALID=1 CALL1_AFTER_VALID=1 TRACE_VALID=1
```

## 判定

1. Master 的 `GLOBAL_BUILD_INIT_CALL_COUNT=1` 是包含本次第一次 boot-script call 的總數；entry snapshot 為 0，`PREBOOT_LAST_CALLER=NONE`。因此沒有觀察到任何更早的 `build_init_readcmd()` 呼叫，也沒有證據支持 `shell_show_build_init()` 先消耗 iterator。
2. 即使沒有 preboot caller，Master 第一次被呼叫時 `p` 仍已在 offset 30，正好是第四條 `ptp start` 的起點；本次讀取 9 bytes 到 offset 39，看到 NUL，沒有看到分號，也沒有觸發 `i == 0` reset。
3. Slave 同一套 global counter/caller snapshot 從 offset 0 正常取出 `vlan off`，到 offset 9 並看到分號；因此本輪 caller audit 和讀取 encoding 在兩張板上均正常工作。
4. 目前最精確的 boundary 是：Master 的 function-static `p` 在任何可觀察的 `build_init_readcmd()` caller 之前就不是 `shell_init_cmd` 起點。由於 global preboot count 為 0，剩下的是 static data initialization、linker/relocation、啟動時記憶體內容，或更早於此 counter 的 state corruption 類問題；本輪不進行修正。

## Step 4 判定

`STEP4_ALLOWED=NO` 維持不變。本輪沒有進行 DMTD /2、threshold、reverse、SoftPLL/FSM 或 PTP functional behavior 的修改或解讀。

## 下一步邊界

等待分支 2 讀取本報告與 raw evidence 後提出下一個單一實驗；在收到新建議前不進行 `p` reset、parser 修正或 Step 4 功能修改。
