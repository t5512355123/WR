# 實驗：EXP-WRPC-MASTER-HISTORICAL-SOF-AB-20260818

## 基本資訊

- Experiment ID：`EXP-WRPC-MASTER-HISTORICAL-SOF-AB-20260818`
- 日期：2026-08-18
- 實驗名稱：已知成功的 9f848ec Master SOF 與最新診斷 SOF A/B
- 本機 branch：`exp/master-9f-observability`
- 目前紀錄 commit：`290114d`（本實驗開始前的 parser 診斷紀錄）
- Source/firmware 基準 commit：`836d1ea38e836f90265c07dc68921c9fe4244723`
- Quartus：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- 本實驗結果 commit：待本紀錄完成後建立（繁體中文 commit message）

## 這次想驗證什麼

前一輪最新診斷版 Master SOF 已成功燒錄，但讀到 `MODE=3/status=0xEF`，沒有重現歷史 `9f848ec` Master 的 `MODE=2/PTP=6/status=0xFF`。本輪只替換 Master SOF，確認差異是在最新編譯映像，還是板端、JTAG board mapping 或 runtime 啟動環境。

## 相較 baseline 唯一修改了什麼

只把 Master FPGA 的 bitstream 換成歷史上已實驗成功的 SOF：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/master.sof
```

沒有修改：

- source code、firmware config、startup command
- Master role 切換方法
- Slave FPGA image
- PHY、QSFP、lane、polarity、pre-emphasis
- PTP filter、servo、SoftPLL、FINC/FDEC、PI、threshold、DDMTD 或 SI5340

## A/B 映像 provenance

| 項目 | Master：歷史 A/B SOF | Slave：本輪維持不變 |
|---|---|---|
| SOF SHA-256 | `383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93` | `3862ffacab7b8d8629dbc8f9cbf8f1c32bbf3936b6ab649819d274f56f2c5fed` |
| MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` | `46ae80d66c95fbd9fb29e04c97515642fcd264c10427bc5fe6d9d65a385881c4` |
| 先前 programmer checksum | `0x30A46449` | `0x309FA629` |
| JTAG cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |

## 燒錄結果

- Master programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-HISTORICAL-SOF-AB-20260818/program_master.log`
- Master SOF checksum：`0x30A46449`
- JTAG ID：`0x02E660DD`
- Quartus Programmer：`0 errors, 0 warnings`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- programmer log SHA-256：`8979e9f7acf9f30b661e914f3ded69014c5f9b6bd37175a01e1c2316f7291d86`
- Slave 本輪沒有重新燒錄，維持表格中的 SOF；因此這是單一變因的 Master A/B，而不是雙板重新編程實驗。

## JTAG/runtime 原始證據

燒錄後以 Quartus 17 唯讀執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \\
  -t scripts/jtag/read_wb_runtime.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \\
  -t scripts/jtag/read_wb_timeseries_session.tcl 30 1000 3
```

原始 log：

- 單次讀值：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-HISTORICAL-SOF-AB-20260818/runtime_single.log`
  - SHA-256：`59ad1350d3b0a7a4fa5ab92fcb962decf3ca6464062d4cb93b6486b0c99dc2ca`
- 30 次、每次間隔 1 秒：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-HISTORICAL-SOF-AB-20260818/runtime_30x1s.log`
  - SHA-256：`08d0e4065bd680d01cdb770386348497236de05a32aec47b61fac6872d304334`

兩個讀值腳本皆由 Quartus 17 SignalTap 執行，30 次腳本最後輸出：

```text
SESSION_TIME_SERIES_DONE
Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

### Master 單次原始結果

`runtime_single.log` 的 Master 區段包含：

```text
cpu_marker: 0x0000B004 seen=1
cpu_debug: ... reset=0 fault=0 im_valid=1
status_probe: ...82FF
```

此刻的 `WDIAGS_MODE=2`、status 低位為 `0xFF`，且 PTP RX/TX 已為 `0x0D/0x0E`。這一瞬間的 PTP state 仍是啟動過渡值 `PTP=4`，所以不能只用單次讀值宣稱已穩定進入 PTP=6。

### Master 30 秒時序結果

- Master sample result：`30/30 accepted=1`。
- Slave sample result：`28/30 accepted=1`；其餘樣本由腳本重試後仍有兩筆未達到腳本的 accepted 條件，這是 Slave 本輪狀態不穩定的證據。
- Master 原始 `DECODE` 多次出現：

```text
status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
```

- Master 原始 `WDIAGS_PTP_META` 多次為 `02010206`，並且原始輸出中可找到 `WDIAGS_PTP:00000006`；Master PTP RX/TX 計數從 `0x12/0x1D` 增加到後續較大的值，表示 PTP 收發路徑有活動。
- Master 的輸出也出現少量 `status_low=F3` 或 `link_up=0` 的取樣列。這些列不能被忽略，因此本紀錄只判定「歷史 Master role 與 time-valid baseline 被恢復」，不把本次 30 秒所有取樣寫成完全無抖動。
- `WR_SIGNAL_REJECT` 共 109 筆，非零 reject `0` 筆，全部為 `count=0 reason=0`。這表示本輪新增的 parser reject counter 沒有指出拒絕原因，但它不是 Master role 成功的必要條件，也不能單獨證明 WR signaling 已完整。

### Slave 原始結果

Slave 多次出現：

```text
status_low=EF time_valid=0 pps_valid=1 wr_mode=3 link_up=1 spll_locked=0
```

並有 `status_low=CF`、`wr_mode=3` 與短暫無 link 的取樣；沒有看到穩定的 `time_valid=1` 或 `spll_locked=1` 證據。Slave 仍是後續要研究的對象。

## Observation

本輪 A/B 唯讀讀值已完成。判準固定為：

```text
Master marker=B004
Master WDIAGS_MODE=2
Master WDIAGS_PTP=6
Master status=0xFF
Master PTP RX/TX 持續增加
```

本輪觀測到 Master 的 `marker=B004`、CPU fault=0、`status=0xFF`、`WDIAGS_MODE=2`、`PTP=6` 以及 PTP RX/TX 活動；因此歷史 Master role baseline 已被重現。由於 30 秒時序中仍有少量 transitional/link-low 取樣，後續報告應保留這個限制，而不是宣稱每一筆取樣都完全穩定。

## Conclusion

本輪的單一變因是 Master SOF。歷史 SOF 將 Master 從前一輪診斷 SOF 的 `MODE=3/status=0xEF` 恢復為歷史上已成功的 `MODE=2/status=0xFF`，並觀察到 `PTP=6` 與 PTP counter activity。這支持：問題位於最新診斷 SOF 所包含的映像、啟動或其 runtime 差異，而不是「DE5a 永遠不能進入 Master role」或本次 JTAG mapping 必然錯誤。

本輪**沒有**證明兩端 White Rabbit 時間同步完成，因為 Slave 仍是 `MODE=3`、`time_valid=0`，也沒有穩定 `spll_locked=1` 證據；本輪也沒有足夠證據指出最新診斷 SOF 的確切 source line 根因。

## Next Step

固定歷史 Master SOF `383c1c65...`，不要再新增 Master role 切換方法，也不要修改 Master 的 PHY、PTP、servo 或 startup command。下一輪只做 Slave 的唯讀 observability：每秒記錄完整 `SSTAT/PSTAT/UCNT/CKO/SETP/FOREIGN_META/PARSE_META/PPS_ESCR/time_valid/pps_valid`，區分卡在 WR parent、servo、SoftPLL lock，還是後段 validity gating。若必須修改 source，先在實驗分支做單一 Slave 變因，Master 永遠保留本輪已證明的歷史映像。
