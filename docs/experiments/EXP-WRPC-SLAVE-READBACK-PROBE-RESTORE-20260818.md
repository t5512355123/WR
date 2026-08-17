# EXP-WRPC-SLAVE-READBACK-PROBE-RESTORE-20260818

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-READBACK-PROBE-RESTORE-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only historical probe-bearing image restore、燒錄後唯讀 runtime 觀測
- Git branch：`exp/master-9f-observability`
- Git commit：`a5a2773`（本輪燒錄前的 source/docs provenance）
- Quartus：Quartus Prime 17.0 Build 595 Standard Edition

## 這次想驗證什麼

上一輪把歷史 positive-control Slave SOF 燒錄成功，但該 image 沒有目前診斷腳本需要的 Sources and Probes，因此無法判斷 runtime。這一輪恢復 repository 中已確認含有 probe、且曾經成功讀出 Slave readback/parent/SoftPLL 欄位的 `079fade...` image，重新建立可觀測的 Slave baseline。

本輪不重新編譯、不修改 Master role、不修改 PHY、PTP、SoftPLL、DMTD、SI5340 或 firmware。Master 完全維持歷史成功的 `9f848ec` image。

## 相較上一輪唯一修改了什麼

只替換 Slave FPGA configuration image：

- 上一輪無 probe restore image：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- 本輪 probe-bearing readback image：`079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13`
- Slave SOF：`artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof`
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- 歷史 Programmer checksum：`0x309FA629`
- Slave cable：`DE5 [1-11.2]`

Master 維持：

- historical source baseline：`9f848ec`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- Master Programmer checksum：`0x30A46449`
- 角色判準：`status=0xFF、WDIAGS_MODE=2、WDIAGS_PTP=6`

## 成功判準

第一層只確認 image/probe 對應成功：

```text
quartus_stp 可以找到 Sources and Probes
status / marker / mailbox 可讀
Slave probe instance 0、1、7、8、10 可正常讀取
```

第二層觀察，不把它預先當成同步成功：

```text
Master：marker=B004、MODE=2、PTP=6、status=FF、PTP RX/TX 有活動
Slave ：marker=B004、MODE=3、link_up=1、parent metadata 可讀
       SSTAT/PSTAT/UCNT、DCO readback 可讀
```

只有同一觀測窗得到 Slave `PSTAT.locked=1、time_valid=1、pps_valid=1`，才可宣稱完成 White Rabbit synchronization。

## 燒錄 command

```text
quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof
```

## MIF / SOF / 燒錄結果

- Slave SOF SHA-256：`079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13`
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Programmer command：`quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof`
- 燒錄開始：2026-08-18 07:06:25（UTC+08:00）
- Programmer operation：07:06:29 開始 configuration，07:06:44 完成
- Programmer version：Quartus Prime Programmer 17.0 Build 595 Standard Edition
- Programmer cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x309FA629`
- configuration result：`Configuration succeeded -- 1 device(s) configured`
- Programmer result：0 errors、0 warnings
- raw programmer log：`artifacts/EXP-WRPC-SLAVE-READBACK-PROBE-RESTORE-20260818/program_slave_readback_probe_restore.log`
- raw programmer log SHA-256：`306e2bf3a85ddb491ca489c1ba062f90ebe52fbb53713b2b3433503cdadc42fe`

## JTAG/runtime 原始結果

燒錄後執行兩組唯讀觀測。由於本輪 Master 維持 `9f848ec` exact image，而該 image 沒有本輪 script 所需的 Sources/Probes，兩組 script 都只在 Slave 端取得有效資料；這不影響 Slave probe/image 對應的判斷，但不能把本輪的 Master 端當成新的 runtime sample。

### HPLL/helper correlation：60 筆、每筆間隔 500 ms

- command：`quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 60 500`
- Master `DE5 [1-11.1]`：`No In-System Sources and Probes instance was found.`
- Slave `DE5 [1-11.2]`：60/60 筆 `HPLL_HELPER_SAMPLE` 成功輸出
- Slave `TAG_SOURCE`：55/60 筆非零，且數值在觀測期間變化
- Slave `LOCK_ENABLE`：60/60 為 `0`
- Slave `LOCK_POLLS`：60/60 為 `0`
- Slave `RCER`：60/60 為 `0`
- Slave `REF/TAG/IRQ/TAG_VALID/TRR_WRITE`：觀測期間均未建立有效活動
- Slave `PSTAT`：有 `0` 與 `1` 的變化，但沒有 `PSTAT.locked=1` 的證據
- Slave `SSTAT`：60/60 為 `0`
- Slave `UCNT`：60/60 為 `0`
- Slave DCO：`STEP=3`、`BUSY=0`；沒有新的 completed step event
- correlation raw log：`artifacts/EXP-WRPC-SLAVE-READBACK-PROBE-RESTORE-20260818/hpll_helper_correlation_60x500ms.log`
- correlation raw log SHA-256：`e3c0e64f1e23eed3343b4fcb90923d08ef811c3aae888061a014517838fb86c8`

### Runtime time-series：20 筆、每筆間隔 1 秒

- command：`quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 20 1000 3`
- Master `DE5 [1-11.1]`：沒有 Sources/Probes，未形成可用 sample
- Slave `DE5 [1-11.2]`：18/20 列 `accepted=1`，2/20 列 retry limit 後 `accepted=0`
- Slave accepted rows：`wr_mode=3、pps_valid=1、time_valid=0、spll_locked=0`
- Slave `link_up`：在 `0` 與 `1` 間出現 transient，沒有形成穩定同步證據
- Slave accepted rows 沒有出現 `time_valid=1` 或 `spll_locked=1`
- runtime raw log：`artifacts/EXP-WRPC-SLAVE-READBACK-PROBE-RESTORE-20260818/runtime_timeseries_20x1s.log`
- runtime raw log SHA-256：`5a2cba2a7a061716dc5169349506a264538000c59b57fefea8137993aa6eef41`

- `status_probe`
- `cpu_marker`
- `WDIAGS_MODE/PTP/PTP_RX/PTP_TX`
- `WDIAGS_SSTAT/PSTAT/UCNT`
- `WDIAGS_FOREIGN_META/PARSE_META`
- DCO state/readback
- correlation raw log 路徑與 SHA-256

## Observation

1. `079fade...` image 與目前 JTAG scripts 的 probe mapping 確實相容：Slave 可讀到完整 60 筆 correlation，證明上一輪 `No In-System Sources and Probes` 是 image/observability mismatch，而不是本輪 Slave JTAG cable 或 script 普遍失效。
2. Slave 有 `TAG_SOURCE` raw activity，但這個活動沒有往下游建立 `WR_LOCK -> RCER -> valid tag/REF/TRR/IRQ -> helper`。
3. Slave `MODE=3` 且 `pps_valid=1`，但在 20 秒 runtime session 中仍沒有 `time_valid=1` 或 `spll_locked=1`；因此尚未完成 White Rabbit synchronization。
4. `link_up` 在部分 sample 為 0，表示現場 runtime/link 狀態仍有 transient；這使本輪更不能把單一 status sample 解讀成穩定同步。
5. Master 本輪沒有可用 Sources/Probes，因此 Master 的 role 只能引用先前 `9f848ec` 的已保存歷史證據，不能宣稱本輪重新驗證了 Master runtime。

## Conclusion

本輪已證明：

1. Slave `079fade...` probe-bearing image 已成功燒錄，且 JTAG probe 與 read-only mailbox 觀測恢復可用。
2. Slave 的 raw `TAG_SOURCE` 有活動，但在本輪 60×500 ms correlation 與 20×1 s runtime 中，沒有證據顯示它進入 `WR_LOCK/RCER/valid tag/SoftPLL helper` 活動。
3. Slave 仍是 `MODE=3、pps_valid=1、time_valid=0、spll_locked=0`，所以本輪沒有完成 White Rabbit synchronization。

證據目前把 Slave 問題優先收斂到：

> `WR parent/signaling -> 收到 LOCK -> WRS_S_LOCK -> wrpc_spll_locking_enable()` 之前或其交界處。

這不是 DMTD polarity 已被證明錯誤，也不是 SI5340 physical output 已被證明失效；目前不改 `g_softpll_reverse_dmtds`，也不改 Master role。

## Next Step

若 probe 恢復但 Slave 仍停在 `time_valid=0`，下一輪只選一個 Slave upstream lock-handoff 相關變因；不改 Master role、不改 DMTD polarity。優先使用現有 read-only evidence 進一步核對 `WR_SIGNAL`、parent flags、`WR_LOCK` 與 `SSTAT/PSTAT` 的同窗關係，必要時才建立一個只增加 upstream lock-handoff sticky observability 的 diagnostic image。若任何新 image 沒有 probe，立即停止功能判讀並先核對 image/script provenance。
