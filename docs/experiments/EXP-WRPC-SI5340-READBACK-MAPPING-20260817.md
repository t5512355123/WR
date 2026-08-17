# 實驗紀錄：SI5340 一般暫存器讀回 mapping 驗證

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-READBACK-MAPPING-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 實驗紀錄建立時 source baseline：待 commit 後填寫

## 這次想驗證什麼

上一輪已讀到 page-independent `0x00FE DEVICE_READY=0x0F`，但 page 3 `0x0339` 讀回 `0x00`，仍不足以確認一般暫存器的 page/address/data mapping 完全正確。本輪改讀專案初始化表明確寫入的 page 0 `0x0021`，預期值為 `0x0F`，並保留 `0x00FE` 作為交叉參考。

若 `page0_0021=0x0F` 且 `device_ready_00FE=0x0F`，可支持一般 page 0 register readback 的 mapping 正常；若只有 DEVICE_READY 正確，則仍需查 page select、register address 或 SDA sampling/shift timing。

## 相較 baseline 唯一修改了什麼

相較於 `a247358` 的 DEVICE_READY 版本：

1. 第一個 readback 由 page 3 `0x0339` 改為 page 0 `0x0021`。
2. page select 由 `0x03` 改為 `0x00`。
3. Tcl probe 欄位名稱由 `page3_0039` 改為 `page0_0021`。
4. 不改 SI5340 DCO write transaction、PHY、PTP filter、servo、SoftPLL threshold、DPLL 或 runtime FSM。

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

待 compile 成功後僅燒錄 Slave `DE5 [1-11.2]`；在燒錄前不宣稱硬體實驗結果。

## JTAG/runtime 原始結果

預定執行：

1. `read_dco_diag.tcl 1000`：保存 ACK 與 `page0_0021/device_ready_00FE`。
2. `read_wb_timeseries_session.tcl 60 1000 3`：確認 readback mapping 變更沒有破壞兩片板 runtime。

## Observation

待燒錄與唯讀觀測後填寫：

- `page0_0021` 是否為預期 `0x0F`
- `device_ready_00FE` 是否為 `0x0F`
- Master/Slave accepted sample 數量
- Slave `SSTAT`、`PSTAT.locked`、`spll_locked`、`time_valid`、`pps_valid`
- parent、PTP、REF/TAG/UCNT activity

## Conclusion

待取得燒錄與 JTAG 原始資料後填寫。即使兩個 readback 都正確，也只能證明目前選定 register 的 I2C readback mapping 可用，不能單獨宣稱 SI5340 output clock effect 或 White Rabbit synchronization 成功。

## Next Step

若兩個 readback 都符合預期，下一輪再設計 SI5340 runtime DCO output clock effect 的單一變因實驗；若不符合，先修正 readback/page/address/data path，不修改 WR 演算法。
