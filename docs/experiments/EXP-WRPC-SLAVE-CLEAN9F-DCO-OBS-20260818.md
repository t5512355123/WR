# 實驗紀錄：clean-9f Slave 加入 DCO 唯讀觀測

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only compile/burn/runtime A/B
- Git branch：`exp/master-9f-observability`
- 實驗紀錄建立前 commit：`a161b2a`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

上一輪的 clean-9f Slave 已重新收到 Master `LOCK` 並進入 `WRS_S_LOCK`，但歷史 SOF 沒有 DCO observability instance，無法直接區分：

```text
SoftPLL 沒有產生 DCO request
        vs.
DCO request 有產生，但 SI5340 I2C transaction 沒完成
```

本輪只在 clean-9f 的 Slave top/controller 上增加唯讀 DCO state、step count、busy/error 與 load pulse probe；不改原本的 WR parser、role、PHY、DDMTD、servo、SoftPLL 設定或 SI5340 transaction state machine。

## 相較 baseline 的唯一變因

- Master：維持 exact historical `9f848ec` SOF，不重新燒錄。
- Slave：以 clean-9f source/MIF/function baseline 為基礎，只增加 DCO observability output 與 altsource probe。
- 不重新產生 firmware MIF；沿用已知 clean-9f Slave MIF。
- 不改功能性 acceptance、startup command、PHY、DCO 控制流程或 clock polarity。

## 預定產物與成功判準

- 預定 Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 預定 clean-9f baseline Slave SOF SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- 新 diagnostic Slave SOF/MIF/QSF、compile log 與 hash 於 compile 後補入。
- 第一層 runtime 判準：仍需看到 `rx_msg=0x1001`、`fail_state=2`、`WR_LOCK polls` 活動。
- 觀測判準：DCO probe 能清楚顯示 step/load/busy/error；這不等於同步成功。
- 最終同步仍必須看到 Slave `spll_locked=1、time_valid=1、pps_valid=1` 並長時間穩定。

## 編譯結果

- pain 已從 GitHub fetch 並 checkout 明確 commit：`1b52223b4bcab4f440189ce95c8219edb811675c`
- 編譯時間：2026-08-18 04:47:48 至 04:48:30（Asia/Taipei）
- Quartus：Version 17.0.0 Build 595 Standard Edition
- Project：`DE5a_wr_slave_jtag`
- 結果：`Full Compilation was successful`，0 errors、270 warnings
- Fitter：`Successful`
- 新 Slave SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- 新 Slave SOF SHA-256：`f57e2b099048a3129ff51b9760a701c1b0ea4306994dbe38b32910d7345cdc1b`
- MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_slave_compile.log`
- Compile log SHA-256：`1bfa74ec67a067691837a9cb4d2edbfb8af8b6bb49f4ba7571cad4622bf33efe`
- Timing：`TIMING_CLOSED=NO`；worst setup `-0.397 ns`、worst hold `-3.537 ns`；這是現有 clean-9f baseline 的 timing 狀態，本輪沒有因 probe 增加而宣稱 timing closure。
- 主要警告：TimeQuest critical warning 332148、3 unconstrained clocks、436 unconstrained input paths、84 unconstrained output paths，以及既有 combinational loop/latch 警告。

本段只代表 compile/Fitter 成功，不代表已燒錄或同步成功。

## 燒錄結果

- 燒錄時間：2026-08-18 04:49:22 至 04:49:40（Asia/Taipei）
- Programmer：Quartus Prime 17.0 Build 595
- JTAG cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- 使用 SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- SOF SHA-256：`f57e2b099048a3129ff51b9760a701c1b0ea4306994dbe38b32910d7345cdc1b`
- Programmer checksum：`0x30A04DFA`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：successful，0 errors、0 warnings
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818/program_slave_dco_obs.log`
- Programmer log SHA-256：`78387eb296527f1f9e154fb62af938987803b5aa6e985905d7ad754603b2a8d6`

這只證明新的 Slave SOF 已成功載入；Master 沒有重新燒錄，Slave servo/SoftPLL/兩片同步仍待 JTAG 證據。

## JTAG/runtime 原始結果

尚未執行。

## Observation

待 compile/burn/runtime 結果補入。

## Conclusion

在尚未 compile、燒錄與觀測前，不對 DCO/SoftPLL 根因下結論，也不宣稱同步成功。

## Next Step

先完成 source-level single-variable patch 與 Quartus compile；若 compile 成功，再由 pain 使用明確 commit 編譯/燒錄，不改 Master。
