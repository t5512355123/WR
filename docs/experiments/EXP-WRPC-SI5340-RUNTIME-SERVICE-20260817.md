# 實驗紀錄：SI5340 runtime DCO transaction service 修正

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-RUNTIME-SERVICE-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 建立前 baseline：`d75112eb5c5f299c0b80af1ce0e34d0838379012`

## 這次想驗證什麼

上一輪 `SI5340-READBACK-MAPPING` 的原始 JTAG 結果顯示：

- Slave `hpll_pending=1`、`rt_state=0`、`bus_state=0`。
- DCO `accepted` counter 有增加，但 `done=0000`。
- readback FSM 完成後 `rb_state=5` 並保持不變。

目前 RTL 在 `rt_state=0` 只允許 `rb_state==0` 時啟動 HPLL runtime transaction；因此 one-shot readback 完成並停在 `rb_state=5` 後，後續 pending DCO request 會永遠不能進入四筆 I2C transaction。這一輪要驗證修正 gate 後，runtime transaction 是否真的完成，並觀察 Slave 是否進一步出現 SoftPLL lock/time-valid 證據。

## 相較 baseline 唯一修改了什麼

相較於 `d75112e`：

1. 在 HPLL runtime service gate 中，允許 `rb_state==5`（readback 已完成）時啟動 pending HPLL DCO transaction。
2. 不改 readback address/data、DCO page/register sequence、DPLL isolation、PHY、PTP filter、servo 或 SoftPLL threshold。

預期硬體證據：

- `hpll_pending` 不再永久維持 1。
- `rt_state` 會走過 1 到 8。
- `DCO done` counter 會大於 0，且 ACK transaction counter 會隨 runtime 增加。
- 若 SI5340 output clock correction 路徑正確，Slave 可能從 `SSTAT=1` 進入後續 servo state；若仍未鎖定，則保留該負面證據。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：待 compile 後填寫
- SDC SHA-256：待 compile 後填寫
- Master MIF SHA-256：本輪不重新燒錄 Master
- Slave MIF SHA-256：待 compile 後填寫
- Slave SOF SHA-256：待 compile 後填寫
- Compile log SHA-256：待 compile 後填寫
- Full Compilation：待 compile 後填寫
- Timing：待 compile 後填寫

## 燒錄結果

待 compile 成功後僅燒錄 Slave `DE5 [1-11.2]`；燒錄前不宣稱硬體實驗結果。

## JTAG/runtime 原始結果

預定執行：

1. `read_dco_diag.tcl 1000`：比較 BEGIN/END 的 HPLL/DPLL source、accepted、done、pending、`rt_state`、I2C ACK 與 readback。
2. `read_wb_timeseries_session.tcl 60 1000 3`：觀察兩片板 runtime 及 Slave `SSTAT/PSTAT/time_valid/pps_valid`。

## Observation

待燒錄與唯讀觀測後填寫：

- runtime DCO `accepted/done` 是否由 `done=0` 改變
- `hpll_pending`、`rt_state`、`bus_state`、`bus_done`
- I2C ACK/error counter
- Master/Slave accepted sample 數量
- Slave `SSTAT`、`PSTAT.locked`、`spll_locked`、`time_valid`、`pps_valid`
- parent、PTP、REF/TAG/UCNT activity

## Conclusion

待取得 compile、燒錄與 JTAG 原始資料後填寫。即使 DCO transaction 完成，也只能證明 FPGA runtime service path 有執行；仍需 `PSTAT.locked=1`、Slave `time_valid=1/pps_valid=1` 並持續穩定，才能宣稱 WR 時間同步成功。

## Next Step

若 `done` counter 開始增加但 Slave 仍未鎖定，下一輪只分析 SI5340 output clock effect 與 helper/servo state；若 `done` 仍為 0，先繼續查 I2C runtime FSM 的 start/busy/done handshake。
