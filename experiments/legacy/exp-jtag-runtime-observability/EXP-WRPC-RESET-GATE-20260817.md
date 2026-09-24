# EXP-WRPC-RESET-GATE-20260817：等待 SI5340 設定完成後才啟動 WR core

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-RESET-GATE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`48a056ef384c293778eefa9542f5b1d42405af0a`
- commit 訊息：`讓 WR core 等待 SI5340 設定完成`

## 這次想驗證什麼

驗證 WR core 與 SoftPLL 是否因為在 SI5340 靜態時鐘設定完成前就解除 reset，導致 DMTD（Digital Dual Mixer Time Difference，數位雙混頻時間差）初始化時沒有看到穩定的 125 MHz 與 124.992 MHz 時鐘。

本輪只驗證一個硬體變因：讓 WR core、PHY 與 JTAG Wishbone mailbox 等待 `si_config_done=1`，並再等待 256 個 50 MHz 週期後才解除 reset。

沒有修改：

- QSFP-A lane 0、lane mapping、polarity 或 TX pre-emphasis
- PTP filter、WR servo 演算法、SoftPLL 演算法
- SI5340 靜態設定表與 DCO register 操作
- Master/Slave 角色與 firmware 原始碼

## Build / 版本證據

- Quartus Prime：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master QSF SHA256：`e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b`
- Slave QSF SHA256：`199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`faf0f2205919abe84347d724e0937bccf06a20ccd01b38551c46951b1a4a46b3`
- Slave MIF SHA256：`b9d0d48f3699ca842da7b552541e227647438e67ceb904fe3829c214324e76aa`
- Master SOF SHA256：`27c7fc2e29421756aa33630f0801d7858f570655eb4e320fb277b743d77025ab`
- Slave SOF SHA256：`ca3758cc9cc5a959e356164e61a0064acf6a476998215d09d75ed266abc59759`
- Master timing：`TIMING_CLOSED=NO`，setup `-2.657 ns`，recovery `-1.919 ns`
- Slave timing：`TIMING_CLOSED=NO`，setup `-2.943 ns`，recovery `-2.390 ns`
- Master/Slave Fitter：`Successful`
- Full Compilation：兩片均 `0 errors`，各 `267 warnings`

原始 build 證據位於 pain：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-RESET-GATE-20260817/
```

## 燒錄結果

### Master

原始 Programmer：`program_master.log`

```text
Cable: DE5 [1-11.1]
Device: 10AX115N2F45@1
JTAG ID: 0x02E660DD
SOF checksum: 0x30A4EA48
Configuration succeeded -- 1 device(s) configured
Quartus Programmer: 0 errors, 0 warnings
```

### Slave

原始 Programmer：`program_slave.log`

```text
Cable: DE5 [1-11.2]
Device: 10AX115N2F45@1
JTAG ID: 0x02E660DD
SOF checksum: 0x30AAE5D7
Configuration succeeded -- 1 device(s) configured
Quartus Programmer: 0 errors, 0 warnings
```

Programmer log SHA256：

- `program_master.log`：`dff0fe08e34637f45b1ea80310bb1488f05cf665318e816220187716ff0ea7fb`
- `program_slave.log`：`c288a5f9a8f0e891b8cbad78fb73f4ef9cbd43b7534777c8501629ed2f4b4c6a`

## JTAG/runtime 原始結果

燒錄後等待 10 秒，使用 Quartus 17 `quartus_stp` 讀取兩片板。原始檔案：

- `runtime_smoke.log` SHA256：`3a17caed499239a3d292c2b9b877f51e6272467a991a198ee5edcd17ef1aa33b`
- `raw_diag.log` SHA256：`00d4ea55324fbe84e6946dd77acefc22b682510ba3794b476597957e34c209e1`

### Master smoke

```text
status_probe: ...82FF
CPU fault=0, marker=0x0000B004, im_valid=1
WDIAGS_MODE: 2
WDIAGS_PTP: 6
WDIAGS_PSTAT: 00000001
```

Master 的 link、PTP runtime 與 time-valid 相關 status 維持正常；Master 不需要等待遠端 parent 才能作為時間來源。

### Slave smoke

```text
status_probe: ...82EF
CPU fault=0, marker=0x0000B004, im_valid=1
WDIAGS_MODE: 3
WDIAGS_PTP: 8
WDIAGS_PSTAT: 00000001
WDIAGS_SSTAT: 00000101
WDIAGS_FOREIGN_META: 03000001
WDIAGS_PARSE_META: 050104D1
WDIAGS_UCNT: 00000003
```

Slave 的 CPU、firmware、PHY/link 與 PTP parent path 都仍在活動，但 `status_probe` 低位的 `time_valid` 仍為 0，`WDIAGS_PSTAT` bit 1 也沒有 SoftPLL lock。

### Slave SoftPLL raw 兩次讀值

在同一 JTAG session 間隔 1000 ms：

```text
RAW_SAMPLE label=BEGIN status=...82EF
RAW_CORE: CTRL=00000001 SSTAT=00000101 PSTAT=00000001 PPS_ESCR=00000000
RAW_LOCK: RESULT=00000001 UNLOCKED=00011EF5 HELPER=00000000 MAIN=00000000
RAW_HW: RCER=00000001 OCER=00000001 TRR_CSR=00020000
RAW_COUNTER: TAG_VALID=00000000 TRR_WRITE=00000000 TAG_SOURCE=11CCCBD3
SHADOW_COUNTER: REF=00000000 TAG=00000000 TAG_VALID=00000000 TRR_WRITE=00000000

RAW_SAMPLE label=END status=...82EF
RAW_CORE: CTRL=00000001 SSTAT=00000101 PSTAT=00000001 PPS_ESCR=00000000
RAW_LOCK: RESULT=00000001 UNLOCKED=00015619 HELPER=00000000 MAIN=00000000
RAW_HW: RCER=00000001 OCER=00000001 TRR_CSR=00020000
RAW_COUNTER: TAG_VALID=00000000 TRR_WRITE=00000000 TAG_SOURCE=11CCCBD3
SHADOW_COUNTER: REF=00000000 TAG=00000000 TAG_VALID=00000000 TRR_WRITE=00000000
```

`TRR_CSR`、部分 raw WB 欄位偶爾會受 mailbox 連續讀取邊界影響，因此只把 frame 中一致且可交叉核對的欄位當作證據。這裡最穩定的證據是：Slave `RCER=1/OCER=1`，但 reference/tag/event counter 仍沒有增加，`UNLOCKED` 仍增加，`spll_check_lock` 仍為 0。

## Observation

1. 等待 SI5340 設定完成後才啟動 WR core 沒有讓 Slave 進入 SoftPLL lock。
2. Slave 仍能執行 uRV/wrpc-sw，CPU fault 為 0，PTP RX/TX 與 parent metadata 存在。
3. Slave 仍是 `link_up=1` 但 `time_valid=0`、`spll_locked=0`。
4. `REF_COUNT/TAG_COUNT/TAG_VALID_COUNT/TRR_WRITE_COUNT` 在 1 秒 raw 觀測中仍為 0。
5. 因此「WR core 太早解除 reset」不是目前已證實的單點根因。

## Conclusion

本實驗只支持以下結論：

> 等待 SI5340 靜態設定完成與額外 reset delay，沒有解決 Slave 的 WR synchronization；目前主要問題仍位於 Slave 的 DMTD tag 產生或其前後的 reference/tag event path。這不是 Root Complex、CPU boot 或 PTP RX 不通的證據，也不能據此宣稱已找到唯一根因。

本輪未達成兩片 `time_valid=1、pps_valid=1、SoftPLL locked=1` 的完成條件。

## Next Step

下一輪仍只改一個變因：加入 per-channel `tags_p` / tag-strobe observability，區分「DMTD 沒有產生 tag」與「tag 產生後未通過 arbitration/FIFO」。不修改 PHY、PTP、servo、SI5340 或 reset gate。若確認 `tags_p` 為 0，再回頭核對 `clk_ref_i=phy_rx_clk`、`clk_dmtd_i=QSFPB_REFCLK_p`、DMTD reset/deglitch 與 recovered RX clock 的實際連接；若 `tags_p` 有活動，才進一步查 arbitration 與 TRR FIFO。

