# 實驗紀錄：SI5340 baseline 冷開機初始化

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 實驗紀錄建立時 Git commit：`16f6d97`（本輪結果補充後會再產生一個紀錄 commit）
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
- 燒錄時間：2026-08-17 10:33:04 至 10:33:24（Asia/Taipei）
- 燒錄 checksum：`0x30A8FEFD`
- JTAG ID：`0x02E660DD`
- Programmer 原始 log：`build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/program.log`
- Programmer log SHA-256：`dc1d3f1ef50ab8ffce4790a89eb11e783b983cd919c5e1bd68edf1e8eb108a58`
- 燒錄結果：`DE5 [1-11.2]` configuration succeeded；Programmer 0 errors、0 warnings。

## 冷開機與 JTAG/runtime 原始結果

本輪已執行並保存：

- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/program.log`
- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/dco_diag.log`
- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/runtime_60s.log`
- `build/artifacts/EXP-WRPC-SI5340-BASELINE-COLDSTART-20260817/runtime_postcheck.log`

補充雜湊：

- `dco_diag.log` SHA-256：`d8f388475921852379d9f18892643db0594000bbd324d0faaed76f089a1ab532`
- `runtime_60s.log` SHA-256：`c379401ad34c65148fff91098e8bd91fb32d451678ead1e771c472e72c4937f9`
- `runtime_postcheck.log` SHA-256：`ca39493876f818160042905122aec56bfc9e73819568399ba38cd8aea9b611fd`

原始觀測摘要：

- Master：60/60 frame accepted。
- Slave：40/60 frame accepted、20/60 rejected；session 有完成 marker。
- DCO：HPLL `accepted=0x0003、done=0x0002`；DPLL `accepted=0x0001、done=0x0000`；I2C errors `0`；readback `page0_0021=0x0F、device_ready_00FE=0x0F`。
- 冷開機後 Slave 曾短暫觀察到 `PTP_RX=3、5、8`，並出現 `FOREIGN_META=0x0000FF01、PARSE_META=0x0001020E`；後續又回到 `PTP_RX=0`。
- postcheck：Master `status_low=FF、time_valid=1、pps_valid=1、link_up=1、PTP_RX=0x634D、PTP_TX=0xF07E`；Slave `status_low=EF、time_valid=0、pps_valid=1、link_up=1、PSTAT.locked=0、SSTAT=0、PTP_RX=0、PTP_TX=0`。

重置方式限制：

- 原先核准的本機實體斷電腳本已嘗試執行，但因找不到 BlueStacks 視窗而未完成實體斷電；本輪後續使用 pain 的 `sudo reboot`，等待約一分鐘後重新連線。
- 因此本輪是「主機 reboot + FPGA 重新燒錄」，不是已證實的實體冷斷電測試；不能把它寫成完整 power-cycle 證據。

## Observation

冷開機與重新燒錄後，Slave 的 link 仍可維持 `link_up=1`，且曾短暫收到少量 PTP frame，但沒有持續 parent/PTP RX 活動；`PSTAT.locked=0、SSTAT=0、time_valid=0`。Master 仍維持已同步狀態。這表示重開機沒有讓 Slave 進入穩定同步。

## Conclusion

本輪沒有達成兩板同步。證據支持的範圍如下：

1. 主機 reboot 與同一 baseline SOF 重新燒錄沒有讓 Slave 穩定進入 `PSTAT.locked=1` 或 `time_valid=1`。
2. Slave 曾短暫出現 PTP RX 與 foreign/parse metadata，代表 PTP 路徑不是在整段觀測期間完全沒有活動；但活動未持續，不能據此宣稱 parent 或 servo 正常。
3. Master 的 `time_valid=1` 不代表 Slave 已同步；目前仍缺少 Slave 的 SoftPLL lock 與 time-valid 證據。
4. 由於實體斷電腳本失敗，本輪不能判定外部 SI5340 是否真正完成 power-cycle reset。

## Next Step

下一步維持 `47ed3f9` baseline，不再恢復 DPLL 或修改 PHY/PTP/servo。先做同一 bitstream 的唯讀 clock/reset/PHY/event-order observability，至少記錄 `clk_sys_625_locked、wr_core_reset_n、core_phy_rst、si_config_done、RX lock-to-ref/data、wr_ready、PTP_RX/TX、foreign/parent、SSTAT/PSTAT` 的時間順序。若該觀測仍顯示 PTP RX 間歇後歸零，再針對 Master→Slave PTP/光路與 WR runtime 設定做單一變因驗證。
