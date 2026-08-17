# 實驗紀錄：SI5340 DPLL/N0 runtime service 恢復

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-DPLL-RESTORE-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 建立前 baseline：`5a8fbf4dcc0a42615ac7d9af8649974e8e1356a0`
- 硬體 source commit：`8cd6b848fd3d3f6a2d8301f0a1322f4b28327b74`

## 這次想驗證什麼

上一輪 HPLL-only 實驗已證明 HPLL/N1 的 runtime transaction 可以完成，但 Slave 仍保持 `PSTAT.locked=0`、`time_valid=0`。本輪驗證完整 WR Slave servo 是否需要 DPLL/N0 主校正路徑：恢復 DPLL pending request 的 runtime service，同時保留 HPLL service 與 readback 完成後的 gate 修正。

## 相較 baseline 唯一修改了什麼

相較於 `5a8fbf4`（硬體 source 為 `47ed3f9`）：

1. 允許 `dpll_pending` 進入與 HPLL 相同的四筆 SI5340 runtime transaction。
2. 當 DPLL 與 HPLL 同時 pending 時，優先服務 DPLL/N0。
3. 將 `dpll_done_once` 的 reset 值改回 0；它只供 JTAG diagnostic 使用，不驅動 WR 行為。

沒有修改：

- PHY、QSFP lane、pre-emphasis、reference clock
- PTP filter、PPSi、servo 演算法與 SoftPLL threshold
- SI5340 static register table、`N_FSTEP_MSK`、`N0/N1_FSTEPW`
- readback sequence、I2C controller 或 Master bitstream

SI5340 官方手冊指出，`0x0339` 的 bit 0/1 分別對應 N0/N1，0 表示啟用 FINC/FDEC；本設計的 DPLL/HPLL runtime mask `0x0E/0x0D` 維持不變。

## 預期證據

- DPLL `accepted` 與 `done` counter 應開始增加。
- DPLL state 的 `pending` 應能被清除，runtime state 應完成 1 到 8 的 transaction。
- I2C error counter 應維持 0。
- 若 DPLL/N0 是缺少的主校正路徑，Slave 應進入 `SSTAT=4/5`、`PSTAT.locked=1`，最後 `time_valid=1、pps_valid=1`。
- 若仍未鎖定，則只能說 DPLL transaction 已執行，不能把 counter 增加當成同步成功。

## 編譯與硬體識別

- Quartus：待編譯後填寫，預期使用 `/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin` Version 17.0.0 Build 595
- QSF SHA-256：待填寫
- SDC SHA-256：待填寫
- Master MIF SHA-256：本輪不重新燒錄 Master
- Slave MIF SHA-256：待填寫
- Slave SOF SHA-256：待填寫
- Compile log SHA-256：待填寫
- Timing：待填寫；若未 closure 必須保留 setup/hold 負 slack

## 燒錄結果

待編譯完成後填寫：

- 燒錄目標：Slave `DE5 [1-11.2]`
- 燒錄時間：待填寫
- Programmer checksum：待填寫
- JTAG ID：待填寫
- Configuration：待填寫
- Programmer log SHA-256：待填寫

## JTAG/runtime 原始結果

待保存以下 pain artifact：

- `build/artifacts/EXP-WRPC-SI5340-DPLL-RESTORE-20260817/dco_diag.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-RESTORE-20260817/runtime_60s.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-RESTORE-20260817/runtime_postcheck.log`

必須記錄：

- DPLL/HPLL source、destination、accepted、done
- `dpll_pending`、`hpll_pending`、`rt_state`、`select_dpll`
- I2C transactions/errors 與 readback
- Master/Slave 60 秒 accepted/rejected
- Slave `SSTAT`、`PSTAT.locked`、`spll_locked`、`time_valid`、`pps_valid`
- `UCNT`、`CKO`、`SETP`、parent metadata 與 PTP activity

## Observation

待燒錄與唯讀觀測後填寫。若 DPLL counter 增加但 `PSTAT.locked` 仍為 0，必須明確記錄為「transaction 執行，但 servo lock 未成立」。

## Conclusion

待燒錄與 JTAG 原始資料完成後填寫。只有在 Slave `PSTAT.locked=1`、`time_valid=1`、`pps_valid=1`，並於長時間取樣中穩定維持，才可宣稱兩張 DE5a 完成 WR 時間同步。

## Next Step

若本輪仍未同步，保留 bitstream 與所有 artifact，依照實際證據只選一個下一個變因；不得同時修改 PHY、PTP、servo 與 SI5340。若本輪同步成功，使用同一 bitstream 做至少 60 秒以上的穩定性重測，再更新最終結論。
