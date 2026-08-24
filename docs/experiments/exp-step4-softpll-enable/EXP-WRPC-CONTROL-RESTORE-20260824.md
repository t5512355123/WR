# EXP-WRPC-CONTROL-RESTORE-20260824

## 實驗基本資料

- 實驗名稱：Slave-only divide A/B 失敗後恢復 control hardware
- 日期：2026-08-24
- Git branch：`exp/step4-control-recovery-fresh`
- Git commit：`60614f536ab5df71bff3c1790886539769aaddcc`
- 目的：將 pain 從失敗的 Slave-only divider image 恢復到已通過 Step 2 / Step 3 的 control image，並以 read-only focused regression 確認恢復成功。

本次沒有修改任何功能 source；使用的是 control branch 已保存的 source。失敗的 `exp/step4-slave-divide-only-fresh` branch 與其實驗紀錄完整保留。

## Fresh build / program provenance

- Quartus：17.0.0 Build 595 / Standard Edition
- Master MIF SHA256：`7d1d0b59a2e5588835595b9b3b7f1dd053c1854ddbb78ebfbd14e198f6c773e2`
- Slave MIF SHA256：`4980ffe0cd1361829968eea55344fe928bad25545bd5e7b875e5695b62ae8855`
- Master SOF SHA256：`3f7f9ecb64fe109260f9787ea901078c612619ff97960d31045a42f9a396218a`
- Slave SOF SHA256：`8f9b5ecac329c17d35143d9c4a15f25de2ea0977acd8bfbdad3e31b5a1a6d6b7`
- Master programmer checksum：`0x30AA3EE5`
- Slave programmer checksum：`0x30B06A0E`
- Master / Slave Quartus build：Fitter 成功，`timing_closed=NO`

## 燒錄結果

Master 使用 `DE5 [1-11.1]`，Slave 使用 `DE5 [1-11.2]`。兩片均回報：

```text
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

## 恢復後 sanity check

燒錄後等待 30 秒，執行：

```text
quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

### Master

- valid samples：20/20
- invalid samples：0
- MAC=`02:00:22:33:44:01`
- MODE=`2`
- PTP=`6`
- PTP_TX delta=`70`
- MiniNIC counters 持續增加
- RXERR=`0`
- 結果：`STEP2_REGRESSION=PASS`

### Slave

- valid samples：20/20
- invalid samples：0
- MAC=`02:00:22:33:44:02`
- MODE=`3`
- PTP=`9`
- PTP_RX / PTP_TX 持續增加
- FOREIGN=`1/0`
- parent flags=`1/0/1`
- RX=`0x1001/1`
- TX=`0x1000/1`
- LOCK=`1`
- LOCK_ENABLE=`4`
- RCER=`0x00000001`
- RXERR=`0`
- 結果：`STEP2_REGRESSION=PASS`、`STEP3_REGRESSION=PASS`

所有 Slave sample 的 current state 仍為 `WRS_IDLE`，所以保留 `POST_STEP3_LOCK_STAGE=TIMEOUT / STATE_EVIDENCE=READ_INCONSISTENT`；這不影響已通過的 Foreign / WR message / LOCK enable evidence，也不把它擴大解讀成新的 functional failure。

## Conclusion

Control image 已恢復，Step 2 / Step 3 focused regression 重新通過，且本次沒有 invalid mailbox sample。pain 目前不再停留在 Slave-only divider 失敗 image。

```text
CONTROL_RESTORE = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS（沿用 control T0：尚未觀測到 downstream acceptance/event/helper activity）
```

這份紀錄只證明 control hardware 已恢復；它不宣稱 Step 4 已完成，也不把 `WRS_IDLE` 單一欄位當成根因。

## 原始證據

- Firmware build：`raw/EXP-WRPC-CONTROL-RESTORE-20260824/master-firmware-build.log`
- Firmware build：`raw/EXP-WRPC-CONTROL-RESTORE-20260824/slave-firmware-build.log`
- Master Quartus build：`raw/EXP-WRPC-CONTROL-RESTORE-20260824/master-quartus-build.log`
- Slave Quartus build：`raw/EXP-WRPC-CONTROL-RESTORE-20260824/slave-quartus-build.log`
- Master programmer：`raw/EXP-WRPC-CONTROL-RESTORE-20260824/master-program.log`
- Slave programmer：`raw/EXP-WRPC-CONTROL-RESTORE-20260824/slave-program.log`
- Restore focused regression：`raw/EXP-WRPC-CONTROL-RESTORE-20260824/step23-20x500.log`

## Next Step

保留這個 control branch/image 作為下一輪 Step 4 實驗的起點。下一次只能從此 control regression PASS 的狀態開始，並且只改一個已通過 source audit 的 Step 4 functional variable。
