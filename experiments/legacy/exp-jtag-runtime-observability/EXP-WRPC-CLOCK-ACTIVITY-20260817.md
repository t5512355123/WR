# 實驗紀錄：WR 時鐘活動與 RX lock 唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-CLOCK-ACTIVITY-20260817`
- 日期：2026-08-17
- 類型：唯讀 JTAG 觀測；本輪沒有重新編譯、沒有燒錄、沒有修改 FPGA 內部行為

## Git 與硬體追溯

- Git branch：`exp/jtag-runtime-observability`
- Git commit：`f94e86d`（新增 `read_clock_activity.tcl`）
- GitHub：`origin/exp/jtag-runtime-observability`
- pain checkout：detached at `f94e86d`
- pain 未追蹤檔案 `quartus/jtag_runtime_diag/cr_ie_info.json` 保留，沒有清除
- 目前板上 SOF：仍是前一輪已燒錄的 `b094621` bitstream，這一輪沒有換 SOF
- Quartus Prime：17.0.0 Build 595

## 想驗證什麼

確認 Slave `time_valid=0` 是否只是因為 QSFPA reference、QSFPB DMTD 或 recovered RX clock 沒有實際活動，並確認 RX transceiver 的 data lock 是否穩定。

## 相較 baseline 唯一修改

唯一修改是新增唯讀 JTAG 腳本 `scripts/jtag/read_clock_activity.tcl`，讀取現有 `clock_activity_probe`（JTAG instance 7）。沒有修改 PHY、QSFP lane、polarity、pre-emphasis、SI5340、PTP filter、servo 或 SoftPLL 控制。

## 觀測方法

每片 FPGA 在同一個 SignalTap source-probe session 內讀取兩次，間隔 60 秒。Probe 欄位為：

- `[15:0]`：QSFPA reference clock 活動計數
- `[31:16]`：QSFPB DMTD clock 活動計數
- `[47:32]`：recovered RX clock 活動計數
- bit 48..50：三個活動 toggle
- bit 51：WR PHY ready
- bit 52：RX lock to reference
- bit 53：RX lock to data

## pain 原始結果

原始檔案：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-CLOCK-ACTIVITY-20260817/clock_activity_60s.log
```

SHA-256：`75a442d8ff62d11bf4dd3b30095bdd28d4aa0f19277914f2faf3ba77fe44e989`

### 60 秒 clock activity

```text
DE5 [1-11.1] BEGIN raw=002B1D6A8C4DE005 REF=57349 DMTD=35917 RX=7530  TOGGLE=1/1/0 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1
DE5 [1-11.1] END   raw=00292F2896E8F1F3 REF=61939 DMTD=38632 RX=12072 TOGGLE=1/0/0 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1

DE5 [1-11.2] BEGIN raw=0038CF0653D4AC9C REF=44188 DMTD=21460 RX=52998 TOGGLE=0/0/0 PHY_READY=1 RX_LOCK_REF=1 RX_LOCK_DATA=1
DE5 [1-11.2] END   raw=002CE0755DC0BDDA REF=48602 DMTD=24000 RX=57461 TOGGLE=0/0/1 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1
```

同一時間窗的完整 runtime/raw 讀取另存於：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-CLOCK-ACTIVITY-20260817/runtime.log
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-CLOCK-ACTIVITY-20260817/raw.log
```

SHA-256：

- `runtime.log`：`b193c65e8edafb4411f7012f48bed31cb1b2a0c8778b571a0fa127f8f4b83d4d`
- `raw.log`：`a15977a2a9f94bae38b49752dd424a2db0a396f6201dfe75a55a7c15019e8aa3`

runtime 讀值顯示 Master 仍可見 `status_low=0x82FF`；Slave 可見 `WDIAGS_MODE=3`、`WDIAGS_PTP=9`、`WDIAGS_SSTAT=0x00000001`、`WDIAGS_PSTAT=0x00000001`、`WDIAGS_UCNT=0x0000009A`，但 Slave status 為 `0x82CF`，`time_valid=0`、`pps_valid=0`。

## Observation

1. 兩片 QSFPA reference clock、QSFPB DMTD clock、recovered RX clock 的活動計數都在 60 秒內變化，因此三個時鐘輸入不是靜止或完全沒有進入 FPGA。
2. 兩片 `PHY_READY=1` 且 `RX_LOCK_DATA=1`，不支持「RX CDR 完全沒有 lock」這個解釋。
3. `RX_LOCK_REF` 在觀測期間出現變化，表示 reference-lock 狀態不如 data-lock 穩定；這是需要後續追查的線索，但不是單獨的 WR SoftPLL lock 證據。
4. Slave 有 PTP、CPU、servo update 活動，但仍沒有 `time_valid=1` 或 `PSTAT` SoftPLL lock 證據。

## Conclusion

這一輪只支持以下結論：

> Slave 的時鐘輸入與 RX data path 有活動，問題不能再優先歸因於「clock 完全沒有輸入」或「RX data CDR 完全沒鎖」。Slave 的 WR servo/SoftPLL 前段仍是主要問題範圍；目前尚未證明根因是 reference-lock、系統時鐘頻率不一致、tagger、calibration 或 time-valid gating 中的哪一項。

另外，現行 top 以 `CLK_50_B2J` 作為 `xwr_core.clk_sys_i`，而 generic WR firmware 與 core 的 system-clock model 使用 `62.5 MHz` 常數。這是下一輪值得做的單一變因，但本輪尚未修改或驗證它。

## Next Step

先保留目前可工作的 bitstream 作為 baseline，下一輪只修正 system timebase mismatch：讓 `clk_sys` 與 firmware/core model 都一致，再重新 compile、燒錄 Master/Slave，並重做相同的 runtime/JTAG 觀測。若仍無法同步，再回到 RX reference-lock、DMTD tag input 與 calibration 的分支。
