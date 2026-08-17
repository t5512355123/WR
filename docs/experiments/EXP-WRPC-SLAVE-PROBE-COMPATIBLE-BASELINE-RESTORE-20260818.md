# EXP-WRPC-SLAVE-PROBE-COMPATIBLE-BASELINE-RESTORE-20260818

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-PROBE-COMPATIBLE-BASELINE-RESTORE-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only known probe-compatible image restore、燒錄後 probe smoke test
- Git branch：`exp/master-9f-observability`
- Git commit：`5ee0281`（燒錄前 source/docs provenance）
- Quartus：Quartus Prime 17.0 Build 595 Standard Edition

## 這次想驗證什麼

上一輪 `6a435...` historical positive-control image 雖然 configuration succeeded，但兩條 JTAG 都找不到 Sources and Probes；後續 `079fade...` readback image 雖可觀測，卻不是最近與目前 DCO instance 8 correlation 流程直接建立 provenance 的 image。本輪恢復最近已用同一套腳本實機讀過 DCO instance 8 的 `001dc7...` start-hold diagnostic image，先只建立可信、可重複的 probe-compatible Slave baseline。

本輪不重新編譯、不修改 Master role、不修改 PHY、PTP、SoftPLL、DMTD、SI5340、firmware 或任何控制暫存器。

## 相較上一輪唯一修改了什麼

只替換 Slave FPGA configuration image：

- 上一輪 Slave：`079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13`
- 本輪 Slave：`001dc7b64afd6ae82dd086126b065f626a8f2c88d6bfa8a95aecbc6198d603ee`
- 本輪 SOF：`quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Programmer checksum：預期 `0x30A22D41`
- Slave cable：`DE5 [1-11.2]`

Master 維持現場既有的 `9f848ec` exact image，不重新燒錄：

- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- Master Programmer checksum：`0x30A46449`

## 燒錄前 probe manifest audit

本輪使用的 source 與腳本在燒錄前做靜態對照：

| 用途 | 腳本讀取 instance | Slave top 對應 | 寬度/用途 |
|---|---:|---|---|
| WR status | 0 | `u_wr_sync_probe` | 64-bit status |
| Wishbone mailbox | 1 | `u_mailbox_probe` | 64-bit source/probe |
| clock activity | 7 | `u_clock_activity_probe` | 64-bit counter |
| DCO runtime | 8 | `u_dco_probe`，`INSTANCE_ID=WR_DCO_ACTIVITY_CLEAN9F_SLAVE` | 64-bit DCO debug |

`read_hpll_helper_correlation.tcl` 需要 instance 0、1、8；`read_wb_timeseries_session.tcl` 需要 instance 0、1、7。current Slave top 對應這些固定 index，因此才允許進行本輪燒錄與 smoke test。這是 source-level provenance；JTAG instance 是否真的存在，仍須燒錄後現場驗證。

## 燒錄 command

```text
quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
```

## 成功判準

本輪只要求 probe smoke test：

1. `start_insystem_source_probe` 成功。
2. Slave instance 0、1、7、8 可讀。
3. 不出現 `No In-System Sources and Probes instance was found` 或 invalid instance index。
4. 只要 smoke test 通過，才允許後續執行長時間 correlation；本輪 smoke test 通過不等於 WR synchronization 成功。

## MIF / SOF / 燒錄結果

- Slave SOF SHA-256：`001dc7b64afd6ae82dd086126b065f626a8f2c88d6bfa8a95aecbc6198d603ee`
- Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- Programmer command：`quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- 燒錄開始：2026-08-18 07:13:48（UTC+08:00）
- Programmer operation：07:13:53 開始 configuration，07:14:07 完成
- Programmer version：Quartus Prime Programmer 17.0 Build 595 Standard Edition
- Programmer cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A22D41`
- configuration result：`Configuration succeeded -- 1 device(s) configured`
- Programmer result：0 errors、0 warnings
- raw programmer log：`artifacts/EXP-WRPC-SLAVE-PROBE-COMPATIBLE-BASELINE-RESTORE-20260818/program_slave_probe_compatible_restore.log`
- raw programmer log SHA-256：`19fb09aa8a02cb8a8bf7375018f890b83cc8210aa910fd5a2bd2c4f9850995f5`

## JTAG/runtime 原始結果

### Probe smoke test

- 執行時間：2026-08-18 07:14:52（UTC+08:00）
- 測試內容：
  - `read_hpll_helper_correlation.tcl 1 0`：讀取 instance 0、1、8
  - `read_dco_state.tcl 0`：讀取 instance 8
  - `read_clock_activity.tcl 0`：讀取 instance 7
- Slave `DE5 [1-11.2]`：三組腳本皆成功取得有效輸出，沒有 `No In-System Sources and Probes` 或 invalid instance index
- HPLL/DCO smoke：`status=A172C0C1275082EF`、`PSTAT=1`、`SSTAT=0`、`UCNT=0`、`TAG_SOURCE=03E68293`、`DCO_DEBUG=00A8000000500320`、`STEP=5`、`BUSY=0`、`ERROR=0`
- DCO decode：`rt_state=0、bus_state=0、bus_done=0、ready=1、busy=0、steps=5、hold=0`
- Slave clock smoke：`PHY_READY=1、RX_LOCK_DATA=1、SYS625_LOCKED=1、CORE_RESET_N=1、SI_DONE=1、PPS_VALID=1、TIME_VALID=0、RX_READY=1、TX_READY=1、LINK_UP=1、LINK_OK=1`
- Master clock probe：可讀到 clock activity，且當時讀值為 `PPS_VALID=1、TIME_VALID=1、LINK_UP=1、LINK_OK=1`；Master mailbox/HPLL scripts 不可讀，因現場 exact image 沒有該 mailbox probe
- raw smoke log：`artifacts/EXP-WRPC-SLAVE-PROBE-COMPATIBLE-BASELINE-RESTORE-20260818/probe_smoke.log`
- raw smoke log SHA-256：`fc88982d6cc023a763bb722993d47f44e56e5009fe68975837be5b9d02b9d4d7`

Smoke test 已通過，因此後續才允許在同一顆 image 上執行 read-only correlation；本節的 smoke 結果本身不等於 WR synchronization 完成。

### Read-only correlation：60 筆、每筆間隔 500 ms

- command：`quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 60 500`
- Slave `DE5 [1-11.2]`：60/60 筆 sample 成功輸出
- `TAG_SOURCE`：58/60 筆非零，數值持續變化
- `STEP_EVENT=1`：3 筆；DCO completed step 約由 `5` 增加至 `25`
- `LOCK_ENABLE`：60/60 為 `0`
- `LOCK_POLLS`：60/60 為 `0`
- `RCER`：60/60 為 `0`
- `REF/TAG/IRQ/TAG_VALID/TRR_WRITE`：觀測期間沒有建立活動
- `HELPER_STATE/HELPER_ERROR/HELPER_OUTPUT`：觀測期間為 `0`
- `SSTAT`：60/60 為 `0`
- `UCNT`：60/60 為 `0`
- raw correlation log：`artifacts/EXP-WRPC-SLAVE-PROBE-COMPATIBLE-BASELINE-RESTORE-20260818/hpll_helper_correlation_60x500ms.log`
- raw correlation log SHA-256：`6e6676ad3438ea3f3f9ce45a90c16b0d2dc4f2afcd47dd6e264c8b9658197fbf`

## Observation

1. `001dc7...` 與目前 diagnostic scripts 的 probe manifest 相容，Slave instance `0/1/7/8` 都能被現場 JTAG 讀取。
2. Slave 的 clock/PHY 基礎狀態在 smoke sample 中是可工作的：`PHY_READY=1、RX_LOCK_DATA=1、LINK_UP=1、LINK_OK=1`。
3. Slave 仍是 `PPS_VALID=1、TIME_VALID=0`；因此 smoke test 沒有證明 White Rabbit time synchronization。
4. Master 的 clock probe 可讀且顯示 `TIME_VALID=1`，但 Master mailbox/HPLL probe 不存在；本輪只能把 Master clock/status 讀值當作補充，不把 mailbox 缺失誤判成 Master runtime failure。
5. 在同一顆 `001dc7...` 上，DCO completed step 可以增加，但沒有同時出現 `WR_LOCK/RCER/valid tag/REF/TRR/IRQ/HELPER` 活動；因此 DCO step 不能被當成 SoftPLL closed-loop 已啟動的證據。

## Conclusion

本輪已證明：

1. `001dc7...` 成功燒錄，且 Slave 的 instance `0/1/7/8` 與 current diagnostic scripts 相容。
2. Slave PHY/link 與 DCO diagnostic interface 可觀測；DCO smoke 顯示 controller idle/ready、沒有 error，已取得 completed step count `5`。
3. Slave 仍只有 `PPS_VALID=1`，`TIME_VALID=0`；本輪沒有完成 White Rabbit synchronization。

4. 在可觀測 baseline 上，第一個明確沒有出現的環節仍是 `WR_LOCK -> RCER -> valid tag/SoftPLL helper`；目前仍沒有證據支持 DMTD polarity 或 SI5340 physical effect 是根因。

本輪只完成了可重複的觀測 baseline，沒有宣稱 Slave 已同步。

## Next Step

下一步仍不改 Master role、不改 DMTD polarity、不寫入控制 register。若要進行功能 A/B，唯一候選應放在 Slave 的 WR parent/signaling 到 SoftPLL lock handoff 交界；在此之前先與目前 read-only 證據一起核對 `WR_SIGNAL`、parent flags、`WR_LOCK` 與 `SSTAT/PSTAT` 的同窗關係，避免把 DCO step 誤當成 lock activity。
