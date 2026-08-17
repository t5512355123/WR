# 實驗紀錄：SI5340 DPLL restore 版本 A/B 回復

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 實驗紀錄建立時 Git commit：`26ea6543c855ad7d47bb8bb620412acc8fa39015`
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
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`ee5f50d96f744ee6fa8723c103591de5593449ceb349474725a53557425e208a`
- Compile log SHA-256：`e2f04fb877a0053170d698608236c99aaf46dc74ec8b1f03d61eb1d0d438e77f`
- Build info SHA-256：`b61826eb5de63e0ed64a04834e4de2b3ea12490a6d603b1a3ee0be315d29f654`
- Full Compilation：成功，0 errors、275 warnings；Fitter successful。
- Timing：未 closure；setup `-0.228 ns`、hold `-3.499 ns`、recovery `1.093 ns`、removal `0.348 ns`；unconstrained clocks 4、inputs 884、outputs 87。

## 燒錄結果

- 燒錄目標：Slave `DE5 [1-11.2]`
- 燒錄時間：2026-08-17 10:17:06 至 10:17:25（Asia/Taipei）
- Programmer checksum：`0x30A8FEFD`
- JTAG ID：`0x02E660DD`
- Configuration：成功，1 device configured；Programmer 0 errors、0 warnings。
- Programmer log SHA-256：`d9fd95b2d6d3b3129f2a9c4323d0eb7f76b1e05ceca1117c5f5f9f1d93926f78`

## JTAG/runtime 原始結果

本輪 pain artifact 已保存：

- `build/artifacts/EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817/runtime_60s.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817/runtime_postcheck.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-AB-RESTORE-20260817/dco_diag.log`

原始 log SHA-256：

- `dco_diag.log`：`d5a9ed901c33f8a7ad525877cebc6417906ad28375551d17f5f10452d29517ca`
- `runtime_60s.log`：`add85530067f9d3b68d6d5638c64976056c446761ba2229842b6b797d22a10c1`
- `runtime_postcheck.log`：`896fdd29e1f25f1559e9c316f87b11282f007c1251548f488c9dad2a2290bca5`

主要原始結果：

- 60 秒 session：Master `60/60 accepted、0 rejected`；Slave `41/60 accepted、19 rejected`；`SESSION_TIME_SERIES_DONE` 存在。
- Master 維持 `time_valid=1、pps_valid=1`；post-check 最終為 `status_low=FF、link_up=1`。
- Slave 可接受 frame 主要為 `status_low=EF、time_valid=0、pps_valid=1、wr_mode=3、link_up=1、spll_locked=0`；post-check 亦為 `status_low=EF、link_up=1`。
- Slave post-check `WDIAGS_SSTAT=0、WDIAGS_PSTAT=1、WDIAGS_PTP_RX=0、WDIAGS_PTP_TX=0`，沒有 parent/servo lock 證據。
- DCO snapshot：HPLL `accepted=0x0003、done=0x0002`；DPLL `accepted=0x0001、done=0x0000`；I2C `errors=0`；readback `page0_0021=0x0F、device_ready_00FE=0x0F`。

## Observation

回復 `47ed3f9` 後，Slave 的 `link_up` 恢復為 1，且 DPLL transaction 幾乎沒有完成；相較上一輪 DPLL restore 的 Slave `E3/link_up=0/PTP_RX=0`，這支持 DPLL restore 版本造成鏈路穩定性下降。但回復版仍沒有 `PSTAT.locked=1`、`time_valid=1` 或 `PTP_RX>0`，所以只排除了本輪的鏈路失效疑點，沒有完成 WR synchronization。

## Conclusion

本輪未完成同步。A/B 證據支持「DPLL restore 版本與 link stability degradation 相關」，但不能單獨證明 DPLL/N0 的時鐘連接或 transaction policy 就是根因；回復版的 Slave 仍卡在沒有 PTP RX/parent 與 SoftPLL lock 的狀態。兩張 DE5a 仍不能宣稱已完成 WR 時間同步。

## Next Step

下一輪保留回復版作為 link-stable baseline，只做唯讀 parent/PTP/clock observability；先找出為何 Slave `PTP_RX=0`，不要再次恢復 DPLL，也不要同時修改 PHY、PTP、servo 與 SI5340。
