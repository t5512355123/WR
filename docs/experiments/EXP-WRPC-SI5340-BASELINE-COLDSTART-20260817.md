# 實驗紀錄：SI5340 baseline 冷開機初始化

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 實驗紀錄建立時 Git commit：待提交
- 硬體 source commit：`47ed3f90e0c0a91d1c71029be92a4b1360b8f4b3`

## 這次想驗證什麼

A/B 回復到 `47ed3f9` 後，Slave `link_up=1`，但 `PTP_RX=0`、`PSTAT.locked=0`。本輪驗證前一輪 DPLL restore 寫入 SI5340 後，僅重新配置 FPGA 是否不足以清除外部時鐘晶片狀態；透過完整冷開機與同一顆 baseline SOF 重新初始化，觀察 Slave PTP parent path 是否恢復。

## 相較 baseline 唯一修改了什麼

- 不修改 RTL、firmware、PHY、PTP、servo 或 SI5340 register table。
- 只增加一次 pain 與連接硬體的完整冷開機/重新初始化，再重新燒錄同一顆 `47ed3f9` Slave SOF。
- Master bitstream 與光纖連線不變。

## 預期證據

- 若冷開機後 Slave `PTP_RX` 開始增加、foreign/parent metadata 出現，表示前一輪有外部 SI5340/初始化狀態殘留。
- 若冷開機後仍 `PTP_RX=0`，則應優先查 Master→Slave PTP/光路或 WR runtime 設定，而不是繼續修改 DPLL。
- 只有 Slave `PSTAT.locked=1、time_valid=1、pps_valid=1` 並長時間穩定，才可宣稱同步成功。

## 編譯、燒錄與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- 本輪使用既有明確 source commit 與重新編譯之 baseline SOF。
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`ee5f50d96f744ee6fa8723c103591de5593449ceb349474725a53557425e208a`
- 燒錄 checksum：待冷開機後重新燒錄填寫
- JTAG ID：待冷開機後重新燒錄填寫

## 冷開機與 JTAG/runtime 原始結果

待執行並保存：

- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/program.log`
- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/dco_diag.log`
- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/runtime_60s.log`
- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/runtime_postcheck.log`

## Observation

待冷開機、重新燒錄與唯讀取樣完成後填寫。所有結論必須區分 link、PTP RX/parent、SoftPLL lock 與 time-valid，不能只用 `link_up=1` 宣稱同步。

## Conclusion

待實驗完成後填寫。

## Next Step

依冷開機後的 PTP RX/parent 證據只選一個下一個變因；若仍為 0，停止修改 DPLL，轉向 Master→Slave PTP/光路與 firmware runtime 設定的唯讀比對。
