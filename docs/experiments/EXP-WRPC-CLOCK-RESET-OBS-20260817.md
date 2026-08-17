# 實驗紀錄：WR 時鐘、重置與 PHY 狀態唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-CLOCK-RESET-OBS-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 硬體 source commit：`a7f28ec27524d15878b4b554620a52dc84628b1f`
- 狀態：燒錄前紀錄；尚未宣稱 compile 或硬體實驗成功。

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
- QSF SHA-256：待 compile 後填寫
- SDC SHA-256：待 compile 後填寫
- Slave MIF SHA-256：待 compile 後填寫
- Slave SOF SHA-256：待 compile 後填寫
- compile log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/compile.log`

## 燒錄與 JTAG 原始結果

待 compile 成功後才可燒錄；欄位先保留如下：

- 燒錄時間：待填寫
- Programmer checksum：待填寫
- JTAG ID：待填寫
- Programmer log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/program.log`
- clock/reset 唯讀 log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/clock_reset_runtime.log`
- postcheck log：`build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/runtime_postcheck.log`

## 既有 baseline 參考證據

在不改 bitstream 的唯讀取樣中，Slave 曾觀察到 `PHY_READY=1、RX_LOCK_DATA=1`，但 `RX_LOCK_REF` 在短時間序列中大多為 0，且偶爾轉為 1；該原始檔為：

- `build/artifacts/EXP-WRPC-BASELINE-CLOCK-READONLY-20260817/read_only.log`，SHA-256 `7581144d66560f1542b95e39ffc333f8587cf99ecd69ede861cb99e443dfc8fd`
- `build/artifacts/EXP-WRPC-BASELINE-CLOCK-READONLY-20260817/clock_series.log`，SHA-256 `8d3f42946f1bba91d3281c9379910c28d0d7e0dfe1949b19c7392388e88f1709`

這些是 baseline 的背景證據，不是本輪新 bitstream 的結果。

## Observation

待 compile、燒錄與唯讀取樣完成後填寫。必須分開描述 clock lock、reset release、PHY ready、link、PTP RX、SoftPLL lock 與 time-valid。

## Conclusion

待實驗完成後填寫。只有 Slave 同時有長時間穩定的 `PSTAT.locked=1、time_valid=1、pps_valid=1`，才能宣稱兩板 WR synchronization 成功。

## Next Step

若觀測顯示 reset/clock/PHY 狀態穩定但 PTP RX 仍歸零，下一步維持此診斷結果，轉向 Master→Slave PTP/parent path 的唯讀比對；不直接修改 DPLL 或 WR 演算法。
