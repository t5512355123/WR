# EXP-WRPC-MASTER-DIAGNOSTIC-BASELINE-20260817

## 實驗名稱

固定 `9f848ec` Master role 的最新 observability diagnostic baseline

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-DIAGNOSTIC-BASELINE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：已知成功 Master 映像重燒錄與 runtime baseline

## 想驗證什麼

在不發明新的 Master role 切換方法的前提下，重新確認歷史成功 baseline 的五項證據：

1. CPU marker 為 `B004`；
2. `WDIAGS_MODE=2`；
3. `WDIAGS_PTP=6`；
4. link up 且 status low byte 為 `0xFF`；
5. PTP RX/TX counter 持續增加。

這五項只用來固定 Master diagnostic baseline，不等於宣稱兩張 DE5a 已完成 White Rabbit 時間同步。

## 相較 baseline 唯一修改

沒有修改。使用已知成功的 `9f848ec` Master role 與目前已驗證可工作的 observability SOF；本次唯一操作變因是重新燒錄同一個 Master SOF 並重新讀取 runtime。

## Git / bitstream provenance

- Branch：`exp/master-9f-observability`
- Git commit：`9af99bb436177af7a716d71ac6bcc194c5d2f849`
- Master role 基底：`9f848ec84b73328daca63b64d2725817e8802e60`
- Quartus：Quartus Prime 17.0 Build 595
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db`

## 燒錄結果

```text
Programming cable: DE5 [1-11.1]
JTAG ID: 0x02E660DD
Programmer checksum: 0x30A46449
Configuration result: Configuration succeeded -- 1 device(s) configured
Quartus programmer: 0 errors, 0 warnings
```

燒錄使用的檔案為：

```text
/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof
```

## JTAG/runtime 原始結果

燒錄後立即執行既有 `read_wb_runtime.tcl`，代表性原始結果如下：

```text
cpu_marker: 0x0000B004 seen=1
WDIAGS_PTP:   00000006
WDIAGS_PTP_RX:00000013
WDIAGS_PTP_TX:00000014
WDIAGS_PTP_META:02010306
WDIAGS_MODE:   2
DECODE: status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
WDIAGS_RXERR: 00000000
```

5 秒時間序列使用：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \\
  -t scripts/jtag/read_wb_timeseries_session.tcl 5 1000 3
```

Master 的有效 frame 在觀測窗內持續顯示 `status_low=FF`、`wr_mode=2`、`link_up=1`、`time_valid=1`、`pps_valid=1`、`WDIAGS_PTP=6`。代表性的 PTP counter 從 `RX=0x29/TX=0x49` 增加到 `RX=0x37/TX=0x69`。

原始 log 與 SHA-256：

```text
artifacts/EXP-WRPC-MASTER-DIAGNOSTIC-BASELINE-20260817/runtime_snapshot.log
413AE3CBB4D0583814041DE55C61BFBE42D5A173D6E41844257FCE6915232BEE

artifacts/EXP-WRPC-MASTER-DIAGNOSTIC-BASELINE-20260817/runtime_timeseries_5s.log
A9ED544622FBB2770BC7326081313FCBE0F5F830964B2490CBFEACE402E2681F
```

## Observation

1. CPU marker `B004` 已出現，且 `fault=0`；runtime firmware 有在執行。
2. Master `WDIAGS_MODE=2`、`WDIAGS_PTP=6`，與 `9f848ec` 歷史成功 role 一致。
3. status low byte 為 `0xFF`，解碼得到 `time_valid=1`、`pps_valid=1`、`link_up=1`。
4. PTP RX/TX counter 在 5 秒觀測窗內增加，表示 PTP 封包路徑有持續活動。
5. 這次只重新燒錄既有 SOF，沒有改 Master role、PHY、startup command 或 PTP/servo 參數。

## Conclusion

本實驗完整通過本輪定義的 Master diagnostic baseline：

```text
marker=B004
WDIAGS_MODE=2
WDIAGS_PTP=6
status_low=0xFF
link_up=1
PTP RX/TX 持續增加
```

因此目前有證據固定 `9f848ec` Master role 與這個 SOF 為可工作的 Master baseline。這個結果**不等於**兩張 DE5a 已完成 White Rabbit 端到端時間同步；Slave 仍需另外取得 `time_valid=1` 與 SoftPLL lock 證據。

## Next Step

保存此 Master image，固定 Master role，不再嘗試新的 Master 切換方法。後續只研究 Slave parent/servo/SoftPLL/DCO feedback 路徑；下一個變因應先針對 Slave DCO transaction 的 request、busy、done、error 觀測，不改 Master、PHY、PTP role 或 lock threshold。
