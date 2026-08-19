# 實驗紀錄：恢復 Slave 已知可進入 lock path 的映像

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-RESTORE-LOCK-PATH-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only 硬體 A/B restore
- Git branch：`exp/master-9f-observability`
- 燒錄前紀錄 commit：`bb4cb3e`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

目前 Master 已固定使用歷史成功的 `9f848ec` SOF。現場 Slave 使用較新的 parser-observability image 時，JTAG 顯示 `WR_SIGNAL rx=0`、`lock_enable=0`，尚未證明進入 `WRS_S_LOCK`。

先前的 clean-9f 配對實驗曾經證明另一份 Slave image 可以收到 Master `LOCK` 並進入 `WRS_S_LOCK`，之後才在 SoftPLL `SEQ_CLEAR_DACS=9` 階段失敗。本輪只恢復那份已知能走到 lock path 的 Slave SOF，藉此區分：

```text
目前 parser-observability image 的 signaling/功能差異
        vs.
已知能進入 WRS_S_LOCK 的 Slave image之後的 SoftPLL問題
```

## 相較 baseline 的唯一變因

- Master：不重新燒錄、不修改，維持 exact `9f848ec`。
- Slave：只由目前的 `3862ff...` parser-observability image 改回保存的 clean-9f Slave image。
- 不修改 source、startup command、Master role、PHY、QSFP、DCO、SoftPLL、SI5340 或 JTAG 控制暫存器。

## 預定使用產物

- 來源 provenance：`18f471070f86eb1ff65534442f8e29cab5520cf8`，base `9f848ec`，observability `584827c`、`302ffc1`
- Slave SOF：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/slave.sof`
- Slave SOF SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 歷史 programmer checksum：`0x30A3C175`
- JTAG cable：`DE5 [1-11.2]`

## 成功判準

本輪不是同步成功判定。第一層判準是重新看到：

- Slave `WR_SIGNAL rx_msg=0x1001` 或等價的 `LOCK` 接收證據
- `fail_state=2` 或明確的 `WRS_S_LOCK` locking path 證據
- `WR_LOCK enable/polls` 開始增加
- `SEQ_CLEAR_DACS`、tag/TRR activity 可被觀察

只有後續還要看到 `spll_locked=1`、`time_valid=1`、`pps_valid=1` 並長時間穩定，才能宣稱兩張 DE5a 完成同步。

## 燒錄結果

- 燒錄時間：2026-08-18 04:31:40 至 04:31:59（Asia/Taipei）
- Programmer：Quartus Prime 17.0 Build 595
- JTAG cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A3C175`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：successful，0 errors、0 warnings
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-RESTORE-LOCK-PATH-20260818/program_slave_restore.log`
- Programmer log SHA-256：`0434ccdb67d410d72a98e886cb1fde300445b47ab1afd2035d76c0daf387b710`

原始 terminal 關鍵結果：

```text
Info (213011): Using programming file .../slave.sof with checksum 0x30A3C175
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

這只證明指定的 Slave SOF 已成功載入，不等於 Slave servo 或兩片同步成功。

## JTAG/runtime 原始結果

- 觀測時間：2026-08-18 04:34:16 至 04:35:06（Asia/Taipei）
- 指令：`quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 10 1000 3`
- Quartus：17.0 Build 595
- 結果：`SESSION_TIME_SERIES_DONE`；Tcl evaluation successful；SignalTap successful，0 errors、0 warnings
- 原始 runtime log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-RESTORE-LOCK-PATH-20260818/runtime_10x1s.log`
- Runtime log SHA-256：`e95ee14aa285492f86890f6ea812b26b68b85bee94211439269678bb0153bcab`

### Master 觀測

- 10/10 samples accepted
- `status_low=0xFF`
- `wr_mode=2`
- `link_up=1`
- `time_valid=1`、`pps_valid=1`
- `WDIAGS_PTP=0x00000006`
- PTP RX/TX counters 持續增加

### Slave 觀測

- 6/10 samples accepted；其餘樣本在 retry 後仍可取得一致的主要欄位，但顯示 JTAG frame 穩定性仍有改善空間
- `status_low` 在 `0xCF` 與 `0xEF` 間變化；`link_up=1`，但 `time_valid=0`
- `wr_mode=3`、`WDIAGS_PTP=0x00000009`
- `WDIAGS_FOREIGN_META=0x03000001`，`PARSE_META` 顯示已看見 WR parent 且已標記 WR/calibrated
- `WR_SIGNAL: rx_msg=0x1001 rx_count=1 tx_msg=0x1000 tx_count=1`
- `fail_role=2 fail_state=2 fail_count=1`，即 Slave 已進入 `WRS_S_LOCK` 路徑
- `WR_LOCK: result=1 spll_locked=0 polls=883696 unlocked=883696 calibration_fail=0 enable=4 seq_state=4`
- `WDIAGS_SSTAT=0x00000001`、`WDIAGS_PSTAT=0x00000001`；`WDIAGS_UCNT` 由 `0x1B` 增加至 `0x22`，表示 servo/SoftPLL 觀測值仍有活動
- `TAG_VALID_COUNT` 與 `TRR_WRITE_COUNT` 持續增加，但 `PSTAT.locked=0`，不能解讀為已鎖定

原始 terminal 關鍵結果：

```text
SESSION_TIME_SERIES_DONE
Info (23030): Evaluation of Tcl script scripts/jtag/read_wb_timeseries_session.tcl was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings

Slave:
WR_SIGNAL: rx_msg=0x1001 rx_count=1 tx_msg=0x1000 tx_count=1 fail_role=2 fail_state=2 fail_count=1
WR_LOCK: result=1 spll_locked=0 polls=883696 unlocked=883696 calibration_fail=0 enable=4 seq_state=4 align_state=0 mode=3
DECODE: status_low=CF time_valid=0 pps_valid=0 wr_mode=3 sstat_wr_valid=1 servo_state=0 link_up=1 spll_locked=0
```

## Observation

1. 恢復舊 Slave image 後，Slave 不再停留在「只送 `SLAVE_PRESENT`、收不到 Master `LOCK`」的狀態；本輪明確看到 `rx_msg=0x1001`，且 `fail_state=2`。
2. 因此本輪單一變因支持：前一版較新的 Slave image 的 signaling/role-to-lock 路徑與這個歷史 lock-path image 不等價；Master 仍維持歷史成功 image，沒有改動。
3. Slave 目前已走到 lock 流程，但 `spll_locked=0`、`time_valid=0`。`UCNT`、TAG/TRR counters 有活動，只能證明伺服路徑在工作，不能證明 SoftPLL 已鎖定。
4. Master 維持 `status=0xFF、mode=2、PTP=6、time_valid=1、pps_valid=1`，所以本輪沒有出現 Master role 回退。
5. 部分 Slave JTAG frame 需要 retry，這是讀取觀測的穩定性問題，不足以否定主要欄位；後續仍應保留 retry 與 frame-valid 標記。

## Conclusion

本輪不能宣稱兩片 DE5a 已完成時間同步。證據支持的最精確結論是：

> 固定歷史 Master baseline 並恢復歷史 Slave lock-path image 後，Master/Slave 的 WR role、PTP signaling 與 parent detection 已通過；Slave 已收到 Master `LOCK` 並進入 `WRS_S_LOCK`，但 SoftPLL 仍未鎖定，因此目前主要未解問題已收斂到 Slave 的 SoftPLL/clock feedback 與其 lock 判定條件，而不是先前的 Master role 切換或基本 signaling。

這個結論仍不是「根因已確定」；下一步要針對 `PSTAT.locked=0`、`SSTAT`、DMTD/servo offset、SoftPLL helper/feedback 與 SI5340 DCO 的證據做唯讀交叉檢查。

## Next Step

1. 保持 Master 的 `9f848ec` 歷史 SOF 完全不變，不再修改 role、PHY 或 startup role command。
2. 暫時保留目前 Slave lock-path image，先做唯讀 SoftPLL/clock-feedback 觀測：`PSTAT.locked`、`SSTAT` state、`UCNT` delta、`CKO/SETP`、DMTD/tag/TRR 活動、`PPS_CR/PPS_ESCR` 與 SI5340 DCO transaction activity。
3. 不先寫入 `WDIAGS_CTRL`、PPS 或 DCO register；若要改硬體或 firmware，只能在完成上述 read-only baseline 後選一個變因。
4. 下一次若要燒錄，先建立新的實驗紀錄並提交，再燒錄；燒錄後立即補 programmer log/checksum，再進行 JTAG。
