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

本節於 probe smoke test 後補入每個 instance 的原始讀值。若 smoke test 通過，後續 correlation 另以獨立實驗紀錄保存。

## Observation

本節只記錄 probe 是否存在與讀值是否符合 manifest，不把 probe 存在誤稱為 WR link 或 time synchronization 成功。

## Conclusion

只有當 instance 0、1、7、8 都能在燒錄後讀取，才能說明本輪恢復了與 current diagnostic scripts 相容的觀測介面；仍須另外取得 Slave `PSTAT.locked=1、time_valid=1、pps_valid=1` 才能宣稱完成 White Rabbit synchronization。

## Next Step

若 smoke test 通過，才在同一 image 上執行 read-only correlation；若不通過，停止功能判讀，先修正 image/source/script provenance，不改 Master role。
