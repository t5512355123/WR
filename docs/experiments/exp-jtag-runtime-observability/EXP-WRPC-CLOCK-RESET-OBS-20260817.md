# 實驗紀錄：WR 時鐘、重置與 PHY 狀態唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-CLOCK-RESET-OBS-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 硬體 source commit：`a7f28ec27524d15878b4b554620a52dc84628b1f`
- 狀態：已完成 compile、燒錄與 60 秒唯讀 JTAG session；本輪未達成 Slave synchronization。

## 這次想驗證什麼

目前 baseline 的 Slave `RX_LOCK_DATA` 大多為 1，但 `RX_LOCK_REF` 大多為 0；同時 Slave PTP RX 在長時間觀測中會歸零。這一輪只想確認以下訊號的時間關係：

- `clk_sys_625_locked`
- `wr_core_reset_n`
- `core_phy_rst`
- `si_config_done`
- `wr_rx_locked_to_ref`
- `wr_rx_locked_to_data`
- `wr_ready / wr_rx_ready / wr_tx_ready`
- `core_tm_link_up / core_link_ok`
- `core_pps_valid / core_tm_time_valid`

目標是區分「核心時鐘/重置條件沒有穩定成立」與「PHY/核心穩定但 PTP parent path 沒有持續資料」。

## 相較 baseline 唯一修改了什麼

- 只把原本 `clock_activity_probe[63:54]` 的零值改成十個既有訊號的唯讀映射。
- 更新 `scripts/jtag/read_clock_activity.tcl` 的解碼與輸出欄位。
- 這些訊號只接到 JTAG source probe，不接回 WR core、PHY、SoftPLL、SI5340 或 reset 控制，因此預期不改變功能路徑。
- 沒有修改 PHY 參數、PTP filter、servo、SoftPLL 演算法、SI5340 register table 或 DCO service。

## Quartus / 編譯資訊

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`f45a648f0e380a5ed0238f2d1030ebea9943cba93066c1f5cbc7247d40aa4a67`
- Full Compilation：0 errors、274 warnings；Fitter successful。
- Timing：`TIMING_CLOSED=NO`、worst setup `-0.178 ns`、hold `-3.487 ns`、recovery `0.465 ns`、removal `0.311 ns`。
- compile log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/compile.log`，SHA-256 `240bc6c8b33cc3aefc297718af125d67c6d006fdf213d5da2daa08b60e4e04ac`
- build info：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/build_info.txt`，SHA-256 `d778a1473224d5f4191b37b2541cc9a66816852f21fa4d61e5d5de7d9691d36d`

## 燒錄與 JTAG 原始結果

本輪已燒錄至 Slave `DE5 [1-11.2]`：

- 燒錄時間：2026-08-17 10:54:32 至 10:54:51（Asia/Taipei）
- Programmer checksum：`0x30A152A4`
- JTAG ID：`0x02E660DD`
- 燒錄結果：configuration succeeded；Programmer 0 errors、0 warnings。
- Programmer log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/program.log`
- Programmer log SHA-256：`40d3db35e2d0bca19bc824f14f9e65ab6809da008da614e1c1b324cd60760557`
- clock/reset 唯讀 log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/clock_reset_runtime.log`，SHA-256 `f3172e63187702dc1c47f374033f5a9722f5417b6bdf4084fd14ee1e0d08462c`
- 完整 60 秒 JTAG log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/runtime_60s.log`，SHA-256 `73d3751c1398dadd577f2a7c2b777d217972017f37d8a92f77be57ee17582d45`

## 既有 baseline 參考證據

在不改 bitstream 的唯讀取樣中，Slave 曾觀察到 `PHY_READY=1、RX_LOCK_DATA=1`，但 `RX_LOCK_REF` 在短時間序列中大多為 0，且偶爾轉為 1；該原始檔為：

- `build/artifacts/EXP-WRPC-BASELINE-CLOCK-READONLY-20260817/read_only.log`，SHA-256 `7581144d66560f1542b95e39ffc333f8587cf99ecd69ede861cb99e443dfc8fd`
- `build/artifacts/EXP-WRPC-BASELINE-CLOCK-READONLY-20260817/clock_series.log`，SHA-256 `8d3f42946f1bba91d3281c9379910c28d0d7e0dfe1949b19c7392388e88f1709`

這些是 baseline 的背景證據，不是本輪新 bitstream 的結果。

## Observation

- 新增 probe 的六個 500 ms 結束窗口中，Slave 的 `SYS625_LOCKED=1、CORE_RESET_N=1、PHY_RST=0、SI_DONE=1、RX_READY=1、TX_READY=1、LINK_UP=1、LINK_OK=1` 都維持有效；因此沒有證據顯示核心長時間卡在 reset 或 system clock 未 lock。
- Slave `RX_LOCK_DATA=1` 在觀測窗口維持；`RX_LOCK_REF` 會在 0 與 1 間變化，`PPS_VALID` 也有一次由 1 變為 0 後恢復，表示 reference/時間有效狀態仍有波動。
- 60 秒 session：Master `60/60 accepted、0 rejected`；Slave `47/60 accepted、13 rejected`，並有 `SESSION_TIME_SERIES_DONE`。
- Slave accepted samples 的共同狀態為：`status_low=EF、time_valid=0、pps_valid=1、link_up=1、spll_locked=0`。Slave `foreign_count=1、foreign_best=0、parent_is_wr=1、parent_calibrated=1` 持續可見，`PTP_RX` 由約 `0x111` 增加至約 `0x26A`，表示 parent/PTP 封包確實有進入。
- 但 Slave `SSTAT` 仍未進入 phase-tracking/lock、`PSTAT.locked=0`、`time_valid=0`；因此問題已從「核心 reset/clock 是否活著」收斂到 parent 已收到後的 servo/SoftPLL 後段，或其輸入資料/clock validity 條件。

## Conclusion

本輪沒有達成兩板 WR synchronization。新增唯讀 probe 沒有改變功能路徑，且證據顯示 Slave 核心時鐘、reset release、PHY ready 與 link 大多正常；同時 parent/PTP data 有活動，但 SoftPLL 沒有 lock，Slave 仍為 `time_valid=0`。因此目前不能宣稱是「核心卡 reset」，也不能只憑 `link_up=1` 宣稱同步成功。

## Next Step

下一步維持此診斷 bitstream 的證據，不直接恢復 DPLL 或修改 WR 演算法。優先比較 Master/Slave 的 PTP parent 欄位、`SSTAT[11:8]` 狀態轉移、`PSTAT.locked`、`UCNT/CKO/SETP` 與 `PPS_ESCR` 的逐秒變化；若 parent 持續有效但 servo state 永不前進，再只選一個 SoftPLL input/validity 條件做功能實驗。
