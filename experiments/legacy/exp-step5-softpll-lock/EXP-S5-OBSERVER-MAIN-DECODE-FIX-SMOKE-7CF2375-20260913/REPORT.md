# EXP-S5-OBSERVER-MAIN-DECODE-FIX-SMOKE-7CF2375-20260913

## 結論

本輪是觀測器修正驗證，`STEP5 = NOT COMPLETE`，且沒有進入 600 秒觀測。

observer 已成功執行並確認修正後腳本可被 Quartus SignalTap 執行，但重新燒錄後的 60 秒 smoke 沒有建立 WR core link：`core_tm_link_up=0`、`core_link_ok=0`、沒有 WR signaling、沒有 DMTD/TAG/TRR/IRQ/SoftPLL activity。因此本輪只證明 reader transport 正常，不能用來判定 Step5。

## 實驗身分

- Branch: `exp/step5-softpll-lock`
- Source commit: `7cf2375189b5e0b525687516074a598ccac92add`
- Board: `DE5 [1-11.2]`，Slave
- Trial: `EXP-S5-OBSERVER-MAIN-DECODE-FIX-SMOKE-7CF2375-20260913`
- Observer exit: `0`
- Observer elapsed: `61896 ms`
- Samples: `38`
- Sample errors: `0`
- Full 600 秒觀測: `未執行；smoke 的 WR_CORE_LINK gate 未通過`

## 本輪唯一修改

只修改：

```text
scripts/jtag/read_step5_startup_timeline_first_divergence.tcl
```

修正 `SPLL_MAIN_STATE` 解碼：

```text
bit 0 = enabled
bit 1 = Main locked
bit 2 = frequency locked
bit 3 = phase locked
```

沒有修改 PI、timeout、bootstrap、guard、arbiter、WR handshake 或 SoftPLL control semantics。

## Build / program gate

- Master/Slave firmware source build 均成功。
- Master/Slave Quartus full compilation 均成功。
- Master/Slave programming 均成功，均為 `0 errors, 0 warnings`。
- Master MIF SHA256: `dabdddff3a98e27a25b6bec2386bc90711dc4dd809e3624bfa26f53c6f946e83`
- Slave MIF SHA256: `8cf63d392ae2366aaf3d4fffdac02854657e137719062dd1c54b36ef706c5191`
- Master SOF SHA256: `d3044ce66a2b3b8486fe552e3d4d070a6fb7f75cd6f722901d19c778fd469a7a`
- Slave SOF SHA256: `6d7cd4e823af027869a09351699bbe466d51208cad76798ecd731bf550d1f0f6`
- Timing closed: `NO`; Master WNS `-0.058 ns`、Slave WNS `+0.015 ns`

## Smoke 結果

observer transport：

- Quartus SignalTap/Tcl exit `0`
- `38 samples`
- `0 sample errors`
- `SPLL_MAIN_STATE` 修正後輸出格式正常，初始 word `00000000` 被解成所有 lock flag 為 0

硬體 startup gate：

```text
FIRST_CORE_TM_LINK_UP_MS=NEVER
FIRST_CORE_LINK_OK_MS=NEVER
FIRST_PTP_RX_ACTIVITY_MS=NEVER
FIRST_DMTD_ACCEPT_MS=NEVER
FIRST_TAG_VALID_MS=NEVER
FIRST_TRR_WRITE_MS=NEVER
FIRST_IRQ_MS=NEVER
FIRST_HELPER_UPDATE_MS=NEVER
FIRST_SPLL_INIT_MS=NEVER
FIRST_MAIN_LOCKED_MS=NEVER
FIRST_PSTAT_LOCKED_MS=17025
FIRST_WR_FAILURE_REASON=NEVER(UNKNOWN)
FIRST_INACTIVE_BOUNDARY=WR_CORE_LINK
```

末端樣本仍是：

```text
WRC_MODE=3(SLAVE)
PTP_STATE=LISTENING
PPSI_PDSTATE=WAIT_MSG
PPSI_EXTSTATE=ACTIVE
WR_RX_SIGNAL=UNKNOWN
WR_TX_SIGNAL=UNKNOWN
SPLL_MODE=DISABLED
SPLL_SEQ_STATE=SEQ_UNINITIALIZED
PSTAT_LOCKED=0
```

`PSTAT_LOCKED_MS=17025` 是 reader 觀察到的 sticky/overlay 欄位變化，但因 upstream link 與 SoftPLL activity 全程未成立，不採用它作為 Step5 證據。

## 離線重算前一輪 raw

本輪也以修正後 mapping 對 `EXP-S5-WR-SLOCK-TRACE-ISOLATED-600S-CDFA3AF-20260913` 的原始 log 做離線重算；結果已保存於：

```text
raw/recomputed-cdfa3af-main-lock.txt
```

重算顯示前一輪 raw 的 Main word 曾在 `0x00000001`（只有 enabled）與 `0x06403105`（enabled + frequency locked，尚未 phase/Main locked）等狀態之間變化；因此前一輪 observer 報告的 frequency/phase/Main 首次時間不能直接採信，修正後的 raw word 才是依據。

## 判定與下一步

本輪不通過 Step5，也不進行功能性 PI/timeout 修改。下一步需先恢復可重現的 startup link gate，並取得一次從有效 WR core link 開始的乾淨觀測；若需要實體冷啟動，應先由使用者確認後再執行。恢復 link 後，沿用已修正 observer，再做 60 秒 smoke，成功後才做 600 秒觀測。

## 原始檔案

- `raw/observer-smoke.log`
- `raw/recomputed-cdfa3af-main-lock.txt`
- `raw/build_info_jtag_master.txt`
- `raw/build_info_jtag_slave.txt`
- `raw/build-master-7cf2375.log`
- `raw/build-slave-7cf2375.log`
- `raw/build-jtag-master-7cf2375.log`
- `raw/build-jtag-slave-7cf2375.log`
- `raw/program-master-7cf2375.log`
- `raw/program-slave-7cf2375.log`
