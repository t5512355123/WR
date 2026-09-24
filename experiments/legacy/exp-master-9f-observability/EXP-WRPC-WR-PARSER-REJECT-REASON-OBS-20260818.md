# 實驗：EXP-WRPC-WR-PARSER-REJECT-REASON-OBS-20260818

## 基本資訊

- Experiment ID：`EXP-WRPC-WR-PARSER-REJECT-REASON-OBS-20260818`
- 日期：2026-08-18
- 類型：診斷版 firmware、Quartus 編譯、雙板燒錄與 JTAG 唯讀觀測
- 本機 branch：`exp/master-9f-observability`
- Git commit：`836d1ea38e836f90265c07dc68921c9fe4244723`
- pain checkout：detached HEAD `836d1ea38e836f90265c07dc68921c9fe4244723`
- Quartus：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

本次燒錄前已確認本機工作樹乾淨，pain 使用 GitHub 明確 commit；pain 原有的 `artifacts/build_info_jtag_slave.txt` 與 `quartus/jtag_runtime_diag/cr_ie_info.json` 未追蹤檔保留不動。

## 這次想驗證什麼

在不改變 White Rabbit（WR）封包接受條件與 Master role 的前提下，確認 Slave 收不到 WR-specific signaling 的原因是否可以由 parser reject reason 直接觀測。主要觀察：

```text
Master historical role baseline
    -> PTP signaling activity
    -> WR TLV parser reject reason/count
    -> Slave WR handshake / SoftPLL handoff
```

## 相較 baseline 唯一修改了什麼

只新增 WR signaling parser 的唯讀診斷：

- `last_reject_reason`
- `reject_count`
- reject reason 對應四個既有 early-return guard：TLV type、OUI、magic、version
- 透過現有 DE5a AUX0 detail register `0x00100950` 暫存並由 JTAG 讀回

沒有修改：

- Master role 切換方法
- `WDIAGS_MODE` / `WDIAGS_PTP` 的角色設定
- PHY、QSFP、lane、polarity、pre-emphasis
- PTP filter、servo、SoftPLL、FINC/FDEC、PI、threshold、DDMTD 或 SI5340
- WR parser 的 acceptance condition 與 state transition

`0x00100970` 沒有被使用，因為該位址在本專案已是 `WDIAGS_SLIDE`；本次使用單一 WR output 設計中未使用的 AUX0 detail slot `0x00100950`。

## 編譯結果

Master 與 Slave 都使用 Quartus 17 完成 Full Compilation，Fitter successful；但兩者 `TIMING_CLOSED=NO`，因此本實驗只能宣稱「產生 SOF 且編譯流程成功」，不能宣稱時序已完全收斂。

| 項目 | Master | Slave |
|---|---|---|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| QSF SHA-256 | `9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d` | `4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233` |
| SDC SHA-256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| MIF SHA-256 | `585880502509e460660d0b2c34c54a01189eefe65338ca23ad8ee3759780e81b` | `46ae80d66c95fbd9fb29e04c97515642fcd264c10427bc5fe6d9d65a385881c4` |
| SOF SHA-256 | `ff5478577697ec8c9d3f4da0dde07d9efe068683fc314a1f23d0bc5fc22a533d` | `3862ffacab7b8d8629dbc8f9cbf8f1c32bbf3936b6ab649819d274f56f2c5fed` |
| Fitter | Successful | Successful |
| Timing closed | `NO` | `NO` |
| Worst setup slack | `-0.462 ns` | `-0.179 ns` |
| Worst hold slack | `-3.493 ns` | `-3.497 ns` |
| Unconstrained clocks | 4 | 4 |

## 燒錄結果

### Master

- Programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-WR-PARSER-REJECT-REASON-OBS-20260818/program_master.log`
- JTAG cable：`DE5 [1-11.1]`
- SOF checksum：`0x30A3363C`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`

### Slave

- Programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-WR-PARSER-REJECT-REASON-OBS-20260818/program_slave.log`
- JTAG cable：`DE5 [1-11.2]`
- SOF checksum：`0x309FA629`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`

## JTAG/runtime 原始證據

本節在燒錄完成後，以同一個唯讀 JTAG session 補入，不寫任何 JTAG control register：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \\
  -t scripts/jtag/read_wb_timeseries_session.tcl 30 1000 3
```

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-WR-PARSER-REJECT-REASON-OBS-20260818/runtime_30x1s.log
```

JTAG session 是否完成、log SHA-256、Master/Slave 的 `MODE`、`PTP`、`link_up`、`time_valid`、`WR_SIGNAL_REJECT`、`WR_LOCK` 與 parser 結果，待本輪讀值完成後補入。

### 本輪 session 結果

- `SESSION_TIME_SERIES_DONE` 已出現。
- `runtime_30x1s.log` SHA-256：`d64f25f28b13a26a074ff1a3d37985d23ba38527ea367ae7ebaea08f8064d447`
- Master：30 筆結果列，29 筆 `accepted=1`；有 3 筆讀到 `WDIAGS_PTP=6`，其餘時間點的 PTP state 主要為 `4`。
- Slave：30 筆結果列，27 筆 `accepted=1`；有效列持續看到 `WDIAGS_PTP=4`，單次 runtime 讀值則為 `WDIAGS_PTP=9`。
- 所有有效診斷列的 `WR_SIGNAL_REJECT` 都是 `count=0 reason=0`，沒有觀測到四個 WR TLV early-return guard 的 reject reason。
- 119 筆包含 reject 欄位的輸出列中，非零 reject count 為 0；`WDIAGS_PTP_META` 的高 byte 沒有出現 `MODE=2`，而是 `MODE=3`。
- 所有列的 decode 都是 `status_low=EF`、`time_valid=0`、`pps_valid=1`、`wr_mode=3`、`link_up=1`、`spll_locked=0`；這不符合本實驗預期的 Master `status=FF/MODE=2` 判準。

另以單次 read-only runtime script 交叉讀取：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-WR-PARSER-REJECT-REASON-OBS-20260818/runtime_single.log
SHA-256: f73ce94fb07696c799d7bdae72212395f83a5812fa6222ff4ba4ad595f23cd77
```

單次原始結果：

```text
Master: marker=0x0000B004, fault=0, im_valid=1,
        WDIAGS_MODE=3, WDIAGS_PTP=4, WDIAGS_PTP_RX=0x1C4,
        WDIAGS_PTP_TX=0x138, status_probe low byte=0xEF

Slave : marker=0x0000B004, fault=0, im_valid=1,
        WDIAGS_MODE=3, WDIAGS_PTP=9, WDIAGS_PTP_RX=0x135,
        WDIAGS_PTP_TX=0x1A5, status_probe low byte=0xEF
```

兩片 CPU 都有 `marker=B004`、`fault=0`、`im_valid=1`，因此 firmware runtime 確實在執行；這不能取代 Master role 判準，也不能宣稱已同步。

## Observation

本輪實際觀察到：

1. 新增的 parser reject observability 沒有報告 reject，故目前不能用 `reject_reason` 指向 TLV type、OUI、magic 或 version 中的任何一項。
2. Master 的 clock/PHY/link 與 CPU runtime 有活動，PTP counters 也會增加；但 `MODE=2/status=0xFF` 沒有重現，Master diagnostic baseline 失敗。
3. Slave 的 `MODE=3`、PTP RX/TX 活動、foreign record 與 link activity 存在，但仍是 `time_valid=0`、`spll_locked=0`；這輪不能把 Slave 的 SoftPLL 問題與 Master role 失敗混在一起判斷。
4. `runtime_30x1s.log` 中的 retry 是 mailbox 跨 register snapshot consistency retry，不是 WR protocol retry；未接受的列沒有拿來拼接結論。

特別保留以下區分：

- `reject_reason=1`：TLV type 不符合
- `reject_reason=2`：OUI 不符合
- `reject_reason=3`：magic 不符合
- `reject_reason=4`：version 不符合
- `reject_count=0`：不代表 handshake 成功，只代表目前未觀測到四個 WR parser guard 的 reject

## Conclusion

本實驗的 compile 與 programming 成功，但功能判準沒有通過：

- 兩片 FPGA 都已正確配置，且 JTAG/CPU/runtime 有活動。
- Master 沒有重現歷史上已知成功的 `MODE=2`、`PTP=6` 穩定狀態與 `status=0xFF`；因此不能宣稱這個最新診斷 SOF 保留了 `9f848ec` Master role。
- Slave 仍未進入可證明的 SoftPLL lock path，且 `time_valid=0`。
- parser reject counter 為零，只能表示本輪沒有觀測到四個 WR TLV guard 的 reject，不能證明 WR signaling handshake 已成功。

因此目前最保守、由證據支持的結論是：

```text
最新診斷映像的 Master runtime role/status 尚未重現歷史 baseline；
在 Master baseline 未恢復前，不應繼續修改或判讀 Slave synchronization 根因。
```

## Next Step

先不修改 source、不增加新的 role 切換方法。依照歷史實驗紀錄的 A/B 建議，使用已知成功的歷史 Master SOF 做一次不改 source 的比較；Slave 維持目前 image 或在同一輪明確記錄其 image。若歷史 Master SOF 恢復 `status=0xFF/MODE=2/PTP=6`，再把差異收斂到最新 top-level/編譯映像；若歷史 SOF 也讀到 `MODE=3`，則優先查 board/JTAG mapping 或 runtime image loading，而不是繼續改 Master role。
