# 實驗紀錄：恢復 Master DCO controller 原始 handshake

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- Source/build commit：`a334630f6b041fb076c0495b5c308dbcc199d9de`

## 實驗名稱

`保留最新唯讀 DCO observability，只恢復成功 baseline 的 runtime handshake`

## 這次想驗證什麼

歷史 SOF A/B 顯示：同一個 Master MIF 與同一個 Master top-level，在舊 DCO controller 下可達到 `MODE=2、status=0xFF`；目前 DCO handshake 修改版則讀到 `MODE=3、status=0xEF`。本次只恢復 DCO controller 的三個 runtime state transition 條件，確認 Master role 是否恢復。

成功判準：

- `marker=B004`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- `status=0xFF`
- `time_valid=1、pps_valid=1`
- PTP RX/TX counter 有活動

這些條件通過仍只代表 Master diagnostic baseline 恢復，不代表兩台 DE5a 已完成同步。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：

- state `3'd1` 從等待 `bus_state` 改回等待 `runtime_start`。
- state `3'd3` 從等待 `bus_state` 改回等待 `runtime_start`。
- state `3'd5` 從等待 `bus_state` 改回等待 `runtime_start`。

保留 `oDCO_DEBUG`、`i2c_state` 與其他唯讀觀測，不修改 Master firmware、startup command、PHY、clock wiring、SoftPLL 演算法或 Slave top-level。

## Build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Project/top-level：`DE5a_wr_master_jtag`
- QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db`
- Fitter：`Successful`
- Compile：`Full Compilation was successful`
- Timing closed：`NO`
- Worst setup/hold slack：`-0.206 ns / -3.504 ns`
- Unconstrained clocks/inputs/outputs：`3 / 402 / 84`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_master_compile.log`
- Compile log SHA-256：`8abf28d33ed60bc512647dca38d79e949e85c06e9ea7131775ea98c657de9b08`

## 燒錄結果

待燒錄後立即補入 programmer 原始輸出、cable、JTAG ID、checksum、結果與 log hash。

## JTAG/runtime 原始結果

待燒錄後以 read-only `read_wb_runtime.tcl`、`read_clock_activity.tcl` 與 `read_wb_timeseries_session.tcl` 讀取。

## Observation

待補入實測結果。

## Conclusion

待補入；只能依 compile、燒錄與 runtime 證據判斷。

## Next Step

若 Master 判準恢復，固定這個 Master source/image，再把相同 DCO controller baseline 帶入 Slave 做下一個單一變因實驗；若未恢復，停止修改 role，回到 DCO transaction/firmware image 證據。
