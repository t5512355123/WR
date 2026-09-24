# EXP-S5-STEP2-CALIBRATION-TIMELINE-FIXED-20260913

## 結論

本輪完成同一 source commit 的 Master/Slave full compile、雙板燒錄，以及 Slave 120 秒 startup timeline 觀測。這不是 Step5 lock pass；但它是有效的上游故障定位實驗，已把失效邊界從「Step2 尚未成立」縮小到：

```text
PTP state 8 UNCALIBRATED
  → PTP state 9 SLAVE
  → pdstate 3 PDETECTED / extension ACTIVE
  → pdstate 4 FAILURE / extension PTP fallback
  → WR WRS_S_LOCK → WRS_IDLE
```

權威觀測結果：

```text
EXPERIMENT_CLASSIFICATION = VALID_UPSTREAM_WR_EXTENSION_FAILURE
SLAVE_STEP1_RESULT        = PASS
SLAVE_PTP_SLAVE_REACHED   = PASS (47822 ms)
SLAVE_WR_EXTENSION        = FAILURE (pdstate=4, extState=2)
SLAVE_WR_HANDSHAKE        = FAILED_FROM_WRS_S_LOCK
STEP4B_RESULT             = BLOCKED_BY_WR_EXTENSION_FAILURE
STEP5_RESULT              = NOT_COMPLETE
PSTAT_LOCKED              = NEVER
MERGE_ALLOWED             = false
```

因此目前不能宣稱 Step4B 或 Step5 PASS，也沒有 merge 到 `main` 的條件。

## Provenance

- 日期：2026-09-13（Asia/Taipei）
- experiment id：`EXP-S5-STEP2-CALIBRATION-TIMELINE-FIXED-20260913`
- branch：`exp/step5-softpll-lock`
- source commit：`e693096563b107a1c6d34f955eaff27e93b27903`
- Pain checkout：同一個 commit
- 硬體：Slave `DE5 [1-11.2]`；Master `DE5 [1-11.1]` 同時完成配對燒錄
- Quartus：17.0.0 Build 595
- 觀測：Slave 120000 ms，68 samples，0 sample errors
- 修正內容：僅修正 timeline observer 對 high-byte mode metadata 的標籤；它實際來自 `wrc_ptp_get_mode()`，不是 protocol-extension state。沒有修改 PI、SoftPLL、WR handshake、arbiter、I2C、reset 或功能性 startup gate。
- cold power-cycle：本實驗窗之前已完成實體斷電重開；修正後 rerun 沒有再重複斷電

## Build and programming

兩張 image 都由同一 commit 產生，full compilation 成功：

| image | result | timing | SOF SHA-256 | MIF SHA-256 |
| --- | --- | --- | --- | --- |
| Master | Full Compilation was successful | `TIMING_CLOSED=NO`, WNS `-0.058 ns` | `9c5e22ffd38dd1e9360dfdc1cef5bb0402e09cf0017bba0193a65bfdd8743e8d` | `1fa5e5a9103466841a5928115550672b20b8434049c0643b22f79dd73437f912` |
| Slave | Full Compilation was successful | `TIMING_CLOSED=NO`, WNS `+0.015 ns` | `d952570d2883caf0bdfd9d3c1beb2e155d6d81c488c803af6108d65d759a781a` | `72037f8f1deb23f37241c843069b121449111a4f698352dbe21d6b4230570e00` |

Master 與 Slave programming 都回報：configuration succeeded、0 errors、0 warnings。原始 build/program log 與 image manifest 保存在 `raw/`。

## Authoritative Slave timeline

### Startup became live

第一筆有效 sample 在 426 ms：

```text
core_tm_link_up=1
core_link_ok=1
wr_rx_ready=1
wr_tx_ready=1
PTP_RX_COUNT / PTP_TX_COUNT = active
RXERR_COUNT = 0
WRC_MODE = SLAVE
PTP_STATE = 8 (UNCALIBRATED)
PPSI_PDSTATE = 3 (PDETECTED)
PPSI_EXTSTATE = 1 (ACTIVE)
WR_STATE = WRS_S_LOCK
LOCK_ENABLE_COUNT = 1
SPLL_INIT_COUNT = 1
TAG/TRR/IRQ/HELPER = active
PSTAT_LOCKED = 0
```

這證明 link、PTP traffic、DMTD/SoftPLL event chain 和 WR lock entry 都有活動；但 event activity 本身不等於 closed-loop lock。

### First meaningful divergence

在 `47822 ms`，下列訊號同一筆 sample 同時改變：

```text
PTP_STATE       8 (UNCALIBRATED) → 9 (SLAVE)
PPSI_PDSTATE    3 (PDETECTED)    → 4 (FAILURE)
PPSI_EXTSTATE   1 (ACTIVE)       → 2 (PTP fallback)
parentIsWRnode  1                → 0
parentCalibrated 1               → 0
WR_STATE        WRS_S_LOCK       → WRS_IDLE
WR_FAILURE      00000000         → 02020001
PSTAT_LOCKED    0                → 0
```

`WR_FAILURE=0x02020001` 與 source packing 一致：

```text
last_fail_role  = 0x02 = WR_SLAVE
last_fail_state = 0x02 = WRS_S_LOCK
failure_count   = 0x0001
```

`wr_handshake_fail()` 會記錄失敗 role/state、將 WR state 設為 `WRS_IDLE`、reset WR servo，並呼叫 `pdstate_disable_extension()`；所以這筆資料支持「WR handshake/extension 在 S_LOCK 階段失敗並退回 PTP fallback」，不是單純 observer 讀錯。

### After failure

在 119076 ms 仍可看到 PTP RX/TX 與 DMTD/TAG/TRR/IRQ/HELPER counters 增加，`RXERR_COUNT=0`，且：

```text
PTP_STATE = 9 (SLAVE)
PPSI_PDSTATE = 4 (FAILURE)
PPSI_EXTSTATE = 2 (PTP)
WR_STATE = WRS_IDLE
WR_FAILURE = 02020001
SPLL_SEQ_STATE = SEQ_WAIT_MAIN
PSTAT_LOCKED = 0
```

`BOOT_GENERATION`、CPU reset、WR-core reset、SI configuration reset 在觀測期間都沒有增加，故本輪不是因為重新開機造成的假象。

## 判定

本輪不能算 Step4B PASS：Step4B 需要 WR extension/handshake 成功維持並進入後續 calibrated/lock path；本輪在 `WRS_S_LOCK` 失敗，extension 被關閉。也不能算 Step5 PASS：`PSTAT_LOCKED` 在整個 120 秒觀測窗都是 0，沒有 closed-loop lock 證據。

本輪也不能把問題歸因於 JTAG/WB transport：timeline 取得 68 筆有效 sample、0 sample errors；link/traffic 活躍且 RX error 為 0。`TIMING_CLOSED=NO` 是 implementation caveat，但目前最早且直接的 runtime 邊界是 WR extension failure。

## 下一步建議

依 `Astra建議\_2.md` 的低擾動原則，下一輪不要再掃 PI，也不要同時更動 SoftPLL 或 transaction arbiter。先做單一目的的 WR extension failure attribution：固定同一 image/source，增加或重用 persistent telemetry，對下列事件建立同一時間軸：

1. Slave 收到 `LOCK` 的時間與 message id/count。
2. `locking_enable()`、`locking_poll()` 的開始、最後 return、timeout/retry 次數。
3. `wr_handshake_fail()` 的時間、role/state、failure count。
4. `pdstate_disable_extension()` 前後的 state。
5. `PSTAT/SSTAT`、`RCER/OCER`、DMTD accepted 與 reset counters。

唯一要回答的問題是：`WRS_S_LOCK` 失敗是 `locking_poll()` 永遠沒有回報 `WRH_SPLL_LOCKED`，還是 WR signal/parent calibration 在同一時刻失去必要條件。只有先回答這個問題、並讓 Step4B 在 settled window 重新 PASS，才回到 Step5 HPLL/PI lock 實驗。

## Raw data

- [Master build log](raw/build-master-e693096.log)
- [Slave build log](raw/build-slave-e693096.log)
- [Master programming log](raw/program-master-e693096.log)
- [Slave programming log](raw/program-slave-e693096.log)
- [Corrected authoritative observer log](raw/observer-e693096.log)
- [Master build info](raw/build_info_jtag_master.txt)
- [Slave build info](raw/build_info_jtag_slave.txt)
- [Raw SHA-256 checksums](raw/checksums.sha256)
