# 實驗紀錄：Slave DCO runtime start 跨時脈保持

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-DCO-START-STRETCH-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only functional A/B
- Git branch：`exp/master-9f-observability`
- 實驗紀錄建立前 commit：`b847dec`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

上一輪 DCO probe 實際讀到：

```text
rt_state=2
hpll_pending=1
dco_busy=1
bus_state=0
bus_done=0
```

現有 DCO controller 的 runtime request 在 50 MHz domain 產生，而 I2C bus controller 使用分頻後的 `i2c_system_clk`。本輪只驗證：把 runtime start 從單一 50 MHz pulse 保持成「直到 bus_state 回應」的 request level，是否能讓 I2C bus 真正進入 busy/completion。

## 相較 baseline 的唯一變因

- Master：維持 exact historical `9f848ec` SOF，不重新燒錄。
- Slave：只修改 `si5340a_controller_dco.v` 的 runtime start request hold；不改 WR parser、role、PHY、DDMTD、servo、SoftPLL threshold、SI5340 register sequence 或 MIF。
- request hold 會在 runtime start 事件發生時置位，並在 `bus_state` 變成 1 後清除；其餘原本 state transition 不變。

## 預定產物與判準

- 沿用 clean-9f MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 第一層：Slave 仍需收到 `LOCK`、進入 `WRS_S_LOCK`。
- 本輪功能判準：DCO probe 的 `rt_state` 能離開 2，並觀察到 `bus_state=1`、後續 `dco_step_count` 或 transaction completion 變化。
- 最終同步判準：Slave `spll_locked=1、time_valid=1、pps_valid=1` 並與 Master 長時間穩定。

## 編譯結果

待 patch 後補入；尚未燒錄。

## 燒錄結果

尚未燒錄。若 compile 通過，燒錄前先提交本段 compile provenance；燒錄後立即保存 programmer log/checksum。

## JTAG/runtime 原始結果

尚未執行。

## Observation

待 compile/burn/runtime 結果補入。

## Conclusion

在尚未完成 A/B 前，不宣稱 start hold 修正有效，也不宣稱同步成功。

## Next Step

先完成 compile；若成功，再以相同 Master/Slave 測試條件燒錄並讀取 DCO probe 與雙板 time-series。
