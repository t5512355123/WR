# 實驗紀錄：恢復 Master DCO controller 原始 handshake

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- Source/build commit：待本次 source commit 完成後補入

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

待 Quartus 17 compile 完成後補入：MIF/SOF/QSF/SDC hash、timing、compile log hash。

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
