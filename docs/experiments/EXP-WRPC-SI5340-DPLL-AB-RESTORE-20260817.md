# 實驗紀錄：SI5340 DPLL restore 版本 A/B 回復

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 實驗紀錄建立時 Git commit：待提交
- 本輪硬體 source commit：`47ed3f90e0c0a91d1c71029be92a4b1360b8f4b3`

## 這次想驗證什麼

上一輪 `EXP-WRPC-SI5340-DPLL-RESTORE-20260817` 在恢復 DPLL/N0 runtime service 後，DPLL transaction 有活動，但觀察到 Slave `link_up=0、PTP_RX=0`，且 Master post-check 也曾變成 `link_up=0`。本輪只回復前一個已知可維持 WR link 的 runtime-service bitstream，驗證鏈路失效是否由 DPLL restore 這一個變因引入。

## 相較 baseline 唯一修改了什麼

- 只把 Slave source 回復到 `47ed3f9` 的 HPLL runtime service 版本。
- 不修改 Master bitstream。
- 不修改 PHY、QSFP lane、pre-emphasis、reference clock、PTP、PPSi、servo、SoftPLL threshold 或 SI5340 static table。
- 本輪不恢復 DPLL pending service。

## 預期證據

- Compile 必須以明確的 `47ed3f9` source commit 完成。
- 燒錄必須記錄 Slave SOF SHA-256、Programmer checksum、JTAG ID 與 configuration 結果。
- 燒錄後使用同一個 read-only JTAG session 讀 Master/Slave；至少觀察 `link_up、PTP RX/TX、SSTAT、PSTAT.locked、time_valid、pps_valid`。
- 若回復後 Slave link 恢復，而 DPLL restore 版本失效，則支持「DPLL restore 造成鏈路穩定性問題」；若仍失效，則不能把問題歸因於 DPLL restore，應回查初始化或板端狀態。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：待 compile 後填寫
- SDC SHA-256：待 compile 後填寫
- Slave MIF SHA-256：待 compile 後填寫
- Slave SOF SHA-256：待 compile 後填寫
- Compile log SHA-256：待 compile 後填寫
- Full Compilation：待 compile 後填寫
- Timing：待 compile 後填寫

## 燒錄結果

- 燒錄目標：Slave `DE5 [1-11.2]`
- 燒錄時間：待燒錄後填寫
- Programmer checksum：待燒錄後填寫
- JTAG ID：待燒錄後填寫
- Configuration：待燒錄後填寫
- Programmer log SHA-256：待燒錄後填寫

## JTAG/runtime 原始結果

待燒錄後保存：

- `build/artifacts/EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817/runtime_60s.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817/runtime_postcheck.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817/dco_diag.log`

## Observation

待 compile、燒錄與唯讀 JTAG 觀測完成後填寫。若只有 link 恢復但 `PSTAT.locked=0/time_valid=0`，只能記錄為「A/B 排除了鏈路失效變因」，不能宣稱 WR 同步成功。

## Conclusion

待實驗完成後填寫。只有在 Slave `PSTAT.locked=1、time_valid=1、pps_valid=1` 並於長時間取樣穩定維持，才可宣稱兩張 DE5a 完成 WR 時間同步。

## Next Step

待本輪證據完成後，只依結果選擇下一個單一變因；不同時修改 PHY、PTP、servo 與 SI5340。
