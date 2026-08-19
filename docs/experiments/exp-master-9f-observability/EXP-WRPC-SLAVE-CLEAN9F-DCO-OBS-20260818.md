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

- 觀測時間：2026-08-18 04:50:00 左右完成（兩組腳本皆 exit 0）
- 雙板 time-series：`read_wb_timeseries_session.tcl 10 1000 3`
- time-series raw log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818/runtime_10x1s.log`
- time-series log SHA-256：`439d4973d09ad77740257772c2c6aefb2772dbd8d4a87f3335d9e6393af58cae`
- DCO probe：`read_dco_activity.tcl 1000`
- DCO raw log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818/dco_activity_1s.log`
- DCO log SHA-256：`d679c3aa2dde237837a1c1c503802c51779f7a3b65eceb101d2a6f5e1dbbe9e8`
- SoftPLL raw mailbox：`read_spll_diag_raw.tcl 1000`
- SoftPLL raw log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818/spll_diag_raw.log`
- SoftPLL log SHA-256：`b7a96c9c9e13aeefaba7cc7d0a562070c80b65c5f394e38536cc99a5a5aa0b81`
- 三個腳本均使用 Quartus 17.0 Build 595；`SESSION_TIME_SERIES_DONE`、Tcl evaluation successful、SignalTap successful，0 errors、0 warnings。

### Master

- time-series 仍以 `status_low=0xFF、wr_mode=2、link_up=1、time_valid=1、pps_valid=1` 為主；Master 沒有重新燒錄。
- DCO 腳本在 Master 回報 `No In-System Sources and Probes instance was found`，這是預期的，因為本輪只在 Slave 加入 instance 8。

### Slave

- `WR_SIGNAL: rx_msg=0x1001 rx_count=1 tx_msg=0x1000 tx_count=1 fail_role=2 fail_state=2 fail_count=1`
- `WR_LOCK: result=1 spll_locked=0 polls=883780 unlocked=883780 calibration_fail=0 enable=4 seq_state=4 align_state=0 mode=3`
- `status_low` 主要為 `0xCF`，少數樣本為 `0xEF`；`time_valid=0`，`link_up=1`。
- DCO probe 原始值：`DCO_ACTIVITY A=FFB800000008ABA2 B=FFB800000008ABA2`

依本輪 probe packing 解碼：

```text
bits[2:0]    rt_state          = 2
bit[3]       bus_state         = 0
bit[4]       bus_done          = 0
bit[5]       static_ready      = 1
bit[6]       dpll_pending      = 0
bit[7]       hpll_pending      = 1
bit[8:9]     prev_valid        = 1/1
bit[10]      select_dpll       = 0  (目前為 HPLL request)
bit[11]      runtime_dir       = 1
bit[14]      runtime_start     = 0
bit[15]      bus_enable        = 1
bit[16:17]   DPLL/HPLL_LOAD    = 0/1
bit[18]      dco_error         = 0
bit[19]      dco_busy          = 1
bits[35:20]  dco_step_count    = 8
```

這表示 request 與 runtime controller 狀態確實有活動，但在取樣前後 1 秒仍停在 `rt_state=2`，沒有觀察到 `bus_state=1` 或 `bus_done=1`。

## Observation

1. compile、燒錄與 JTAG 均完成；Master baseline 沒有被重新燒錄。
2. clean-9f Slave 的 signaling 結果維持 positive control：已收到 Master `LOCK`，`fail_state=2`，`WR_LOCK enable=4` 且 polls 持續存在。
3. 新 DCO probe 顯示 HPLL input load 已被看到、`hpll_pending=1`、`dco_busy=1`，但 runtime controller 在 1 秒前後都停在 state 2，`bus_state=0`、`bus_done=0`。
4. 因此本輪最強的新證據是：DCO request 已進入控制器，但目前看到的 I2C bus handshake 沒有進入 busy/completion。這仍不能單獨證明是 SI5340 實體 ACK、I2C clock domain、或 bus controller start pulse 的哪一個環節。
5. `dco_error=0` 不代表 transaction 成功；它只代表目前 controller 沒有設置自己的 error bit。`dco_step_count=8` 也只能表示曾有完成計數，不能表示目前 pending request 已完成。

## Conclusion

本輪已成功建立可讀的 DCO diagnostic baseline，但兩台 DE5a 尚未同步。證據把 blocker 再縮小為：Slave 已收到 `LOCK`，SoftPLL/DCO request 有活動，但 clean-9f DCO controller 的目前觀測點停在 `rt_state=2、bus_state=0、bus_done=0`，因此最值得優先驗證的是 DCO runtime controller 到 I2C bus controller 的啟動握手。這是 leading hypothesis，不是已證明的 SI5340 硬體故障。

## Next Step

1. 不改 Master、不改 WR parser、role、PHY 或 SoftPLL threshold。
2. 只做 source-level read-only audit：逐 cycle 對照 `rt_state=1/2`、`runtime_start`、`bus_enable`、`bus_start`、`bus_state` 與 `oCONFIG_DONE`，確認 state 2 為何沒有看到 bus busy。
3. 若必須做下一個功能 A/B，只修一個明確的 bus-start/clock-domain handshake，並先建立新的實驗紀錄、compile、保存 provenance，再燒錄。
4. 下一輪燒錄後先重跑 DCO probe；只有當 DCO transaction 能離開 state 2 且 `spll_locked/time_valid/pps_valid` 成立，才進行長時間兩板同步驗證。
