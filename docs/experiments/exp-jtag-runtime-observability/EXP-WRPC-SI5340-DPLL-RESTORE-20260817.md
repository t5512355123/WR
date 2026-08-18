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

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：本輪不重新燒錄 Master
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`a7435342666e2656a17ce6909b7446d09965c87c30d415eef3a6667fb9572a5f`
- Compile log SHA-256：`0d4d07c9875d16b5aaa6a7c476033fa7c9954220f1d48c51c71adb17d61e148e`
- Full Compilation：成功，0 errors、274 warnings；Fitter successful。
- Timing：未 closure；setup `-0.364 ns`、hold `-3.514 ns`、recovery `1.275 ns`、removal `0.297 ns`；unconstrained clocks 4、inputs 887、outputs 83。

## 燒錄結果

- 燒錄目標：Slave `DE5 [1-11.2]`
- 燒錄時間：2026-08-17 10:00:21 至 10:00:40（Asia/Taipei）
- Programmer checksum：`0x30A4B657`
- JTAG ID：`0x02E660DD`
- Configuration：成功，1 device configured；Programmer 0 errors、0 warnings。
- Programmer log SHA-256：`ba902ab386876b4128da5f3505fca7603b21244f8f23145648e886c98f545804`

## JTAG/runtime 原始結果

本輪 pain artifact 已保存：

- `build/artifacts/EXP-WRPC-SI5340-DPLL-RESTORE-20260817/dco_diag.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-RESTORE-20260817/runtime_60s.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-RESTORE-20260817/runtime_postcheck.log`
- `build/artifacts/EXP-WRPC-SI5340-DPLL-RESTORE-20260817/dco_diag_after.log`

原始結果與雜湊：

- `dco_diag.log` SHA-256：`7ed49d8d7376a73f6bb55c75ca10c376c429db15adc21caf31209d2feba3049b`
- `runtime_60s.log` SHA-256：`71b8b498f0b64241fda322335925b4d0a0da0ebbdb253c552142f9a126e20a0b`
- `runtime_postcheck.log` SHA-256：`634b4b8419b7f9ebd4b0dfb790b68d0e911c614b4c2971625af9c2fe3f091cf5`
- `dco_diag_after.log` SHA-256：`9eba2af48dc6b3aa5ae21ace73526529d292e64e0201acc93f62bdf3d1e24cb9`

主要原始結果：

- 60 秒 session：Master `60/60 accepted、0 rejected`；Slave `58/60 accepted、2 rejected`；`SESSION_TIME_SERIES_DONE` 存在。
- Master 在 session 前段曾讀到 `status_low=FF、time_valid=1、pps_valid=1、link_up=1`；post-check 讀到 `status_low=F3、time_valid=1、pps_valid=1、link_up=0`。
- Slave 讀到 `status_low=E3、time_valid=0、pps_valid=1、wr_mode=3、link_up=0、spll_locked=0`；`WDIAGS_PSTAT=0`、`WDIAGS_SSTAT=0`、`WDIAGS_PTP_RX=0`。
- DCO 診斷開始/結束均顯示 DPLL 與 HPLL transaction 有活動；post-burn after snapshot 為 DPLL `accepted=0x0017、done=0x000C`、HPLL `accepted=0x0024、done=0x0018`。
- DCO I2C `errors=0`，readback `page0_0021=0x0F、device_ready_00FE=0x0F`。
- `dpll_pending=0、hpll_pending=0、rt_state=0、static_ready=1`；這表示本輪的 pending request 有被服務，但不代表輸出時鐘已對 WR clock tree 產生正確效果。

## Observation

本輪確認 DPLL runtime transaction 確實執行，且 I2C ACK/readback 沒有錯誤；但是 DPLL restore 版本沒有讓 Slave 進入 servo lock。除了 Slave 一直沒有 parent/PTP RX/link，Master 在 post-check 也從 session 前段的 `link_up=1` 變成 `link_up=0`。因此本輪出現「鏈路穩定性下降」的證據，不能把它解讀成單純的 lock 尚未完成。

需要保留的證據界線：

- 已證明：DPLL/HPLL runtime transaction 有被接受並完成部分 transaction；I2C error counter 為 0；DEVICE_READY/readback 值可讀。
- 尚未證明：DPLL/N0 的 SI5340 輸出真的連到正確的 WR clock input，也尚未證明其輸出頻率/相位調整方向正確。
- 已觀察到：Slave `PTP_RX=0、link_up=0`，以及 Master post-check `link_up=0`；這是本輪 bitstream/runtime 的失敗證據。

## Conclusion

本輪失敗。DPLL restore 確實讓 DPLL transaction 開始活動，但未完成 Slave WR synchronization；Slave 沒有 `PSTAT.locked=1`、`time_valid=1`，且 `PTP_RX=0/link_up=0`。Master post-check 亦為 `link_up=0`。因此目前最保守且由證據支持的結論是：**本變更尚未證明是缺少的 servo 校正路徑，反而引入了 WR/link clock 穩定性疑點。** 不能宣稱兩張 DE5a 已同步。

## Next Step

保留本輪 bitstream 與所有 artifact，下一輪只做 A/B 回復：重新燒錄上一個已知可維持 `link_up=1` 的 `5a8fbf4`/`47ed3f9` 硬體版本到 Slave，不修改 Master、PHY、PTP 或 servo，確認鏈路是否恢復。若回復後鏈路恢復，才可把本輪的 DPLL restore 視為造成鏈路失效的高度可疑變因；若仍失效，則先查燒錄後初始化或板端狀態，不再繼續加 SI5340 runtime 功能。
