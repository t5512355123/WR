# EXP-WRPC-STEP4-RUNTIME-CONTEXT-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-RUNTIME-CONTEXT-20260820`
- 日期：2026-08-20（Asia/Taipei）
- Branch：`exp/step4-softpll-enable`
- 狀態：**雙板已以 fresh SOF 燒錄成功；Slave context 已判定為 A1a，Step 4 仍未完成**

## 這次想驗證什麼

目前 fresh SOF 已觀察到 Slave：

```text
RCER=1、LOCK_ENABLE=4、SPLL_STATE=SEQ_CLEAR_DACS
TAG_VALID/TRR_WRITE/IRQ/HELPER_UPDATE_COUNT = 0
```

本輪只分辨兩種 runtime 情況：

1. `spll_init()` 或 `SEQ_CLEAR_DACS` 反覆被重新執行。
2. init 次數沒有增加，但 DAC timeout 已經過期，仍沒有 raw tag-driven IRQ。

## 相較 baseline 的唯一修改

只增加 read-only observability：

- firmware runtime counters：`spll_init_count`、`SEQ_CLEAR_DACS_entry_count`
- timer shadows：`current_tics`、`dac_timeout`、`last_init_tics`、`last_clear_dacs_tics`
- WDIAGS offsets：`0x13C..0x150`
- JTAG script：`scripts/jtag/read_step4_runtime_context.tcl`
- WDIAGS DPRAM 深度由 85 words 提供到 `0x150`

沒有修改：

- Master/Slave role、MAC、PHY、Simple Word Alignment、PTP/PPSI
- WR signaling 行為
- SoftPLL state transition、tagger enable、IRQ、PI、lock threshold
- DDMTD polarity、DCO gain、SI5340 控制

## 預期判讀

```text
Case A1a：INIT_COUNT 不增加、CLEAR_DACS_COUNT 不增加，
          CURRENT_TICS 已超過 DAC_TIMEOUT，raw event 仍為 0
          => init 後沒有 tag-driven IRQ/event。

Case A1b：INIT_COUNT 或 CLEAR_DACS_COUNT 增加，
          => runtime re-init 或 sequence reset loop。
```

## 建置與燒錄 provenance

本輪 exact commit 與 fresh build provenance：

- Git commit / branch：`ae9ca1769dad08430ab49c5b2e0f52f307259c7f` / `exp/step4-softpll-enable`
- Quartus：`17.0.0 Build 595`
- Master MIF SHA256：`84b9f9b65a094f3a9ec5045ef8733387329801983e7709f45c1da32a8204604f`
- Slave MIF SHA256：`7ee5e9f3a0197d1e5ca358bb10bbaaf0c351354cacf8f32e816838d1e2056e27`
- Master SOF SHA256：`774d1552991749475918a4c42c34fcb71fc7b0fc57f73ae476511613f821f726`
- Slave SOF SHA256：`e68e011e542d8a770475dddf0155f2413239fef44759f6428043b59ec1b69aac`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master/Slave compile：`Full Compilation was successful`；timing report `TIMING_CLOSED=NO`
- Master Programmer：成功，checksum `0x30A5EF0D`，原始輸出 `program_master_20260820.log`
- Slave Programmer：成功，checksum `0x30A4A104`，原始輸出 `program_slave_20260820.log`

## JTAG 原始結果

已保存雙板 fresh SOF 燒錄後的原始輸出：

- `jtag_step4_runtime_context_20260820.log`
- 執行指令：`quartus_stp -t scripts/jtag/read_step4_runtime_context.tcl 10 1000`
- `jtag_runtime_after_runtime_context_20260820.log`：`read_wb_runtime.tcl` 的 Step 1～3 gate snapshot
- `jtag_hpll_helper_runtime_context_20260820.log`：10 次、每次間隔 1 秒的 HPLL/helper correlation

### Step 1～3 acceptance snapshot

來源：`jtag_runtime_after_runtime_context_20260820.log`。這份 snapshot 證明本輪 fresh SOF 仍保留既有的 Step 1～3 行為：

| Gate | Master | Slave | 判定 |
|---|---|---|---|
| CPU marker / runtime | `B004`, `reset=0`, `fault=0`, `im_valid=1` | `B004`, `reset=0`, `fault=0`, `im_valid=1` | PASS |
| Endpoint MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` | PASS |
| Role | `MODE=2`, `PTP=6` | `MODE=3`, `PTP=9` | PASS |
| MiniNIC counters | `TX=0x3EB`, `RX=0x219` | `TX=0x1F7`, `RX=0x35D` | 有活動 |
| PPSI/PTP counters | `PTP_RX=0x155`, `PTP_TX=0x2F9` | `PTP_RX=0x2B9`, `PTP_TX=0x9E` | 有活動 |
| Foreign Master | 不適用 | `FOREIGN_META=0x03000001` | PASS |

本輪仍未將 `time_valid` 或 `PSTAT.locked` 當作 Step 4 gate；它們屬於後續 SoftPLL lock/closed-loop 階段。

Slave 的 10 秒 time-series 穩定得到：

```text
SPLL_STATE          = 00030009 (SEQ_CLEAR_DACS)
RCER                = 00000001
OCER                = 00000001
INIT_COUNT          = 00000004 (全程不增加)
CLEAR_DACS_COUNT    = 00000001 (全程不增加)
CURRENT_TICS        = 0001165E -> 00013D6E (持續增加)
DAC_TIMEOUT         = 00000000
LAST_INIT_TICS      = 0000E02B (固定)
LAST_CLEAR_TICS     = 00003063 (固定)
TAG_VALID/TRR_WRITE = 0/0
REF/TAG/IRQ         = 0/0/0
HELPER_UPDATE       = 0
```

`CURRENT_TICS` 持續增加而 `INIT_COUNT`、`CLEAR_DACS_COUNT` 不變，表示觀測期間沒有 repeated re-init 或 repeated CLEAR_DACS entry。`DAC_TIMEOUT=0` 且 state 長時間停在 `SEQ_CLEAR_DACS`，符合 `sequencing_fsm()` 尚未被 raw tag event 驅動到設定 timeout 的 A1a：init 後沒有 tag-driven IRQ/event。這不是 DCO actuator 證據。

### HPLL/helper correlation 結果

來源：`jtag_hpll_helper_runtime_context_20260820.log`。Master 沒有對應的 In-System Sources and Probes instance，因此 script 明確記錄：`No In-System Sources and Probes instance was found.`；Slave 則成功取得 10 次樣本：

- `UCNT` 由 `0x22` 增加到 `0x26`，表示背景 servo/diagnostic polling 仍有活動。
- `SPLL_STATE=0x00030009`、`RCER=1`，但 `TAG_VALID=0`、`TRR_WRITE=0`、`IRQ=0`、`HELPER_UPDATE_COUNT=0`、`STEP=0` 全程不變。
- `TAG_SOURCE=0x0BC79F0`、`DAC_HPLL=0x010003E8`、`DAC_MAIN=0x010002E8` 在樣本中保持不變；`HPLL_LOAD=0`、`BUSY=0`、`ERROR=0`。

因此這組 correlation 觀測沒有顯示 helper correction 或 HPLL/DCO request 已被 tag event 啟動；它與 A1a「停在 raw tag/TRR/IRQ 之前」的判定一致。

## Conclusion

本輪判定 **A1a：SoftPLL init 後沒有可觀察的 raw tag-driven IRQ/event**。目前沒有 repeated init loop 證據；第一個停點在 `TAG_VALID/TRR_WRITE` 之前或附近，而不是 helper correction/DCO actuator。Step 1～3 的 Endpoint/MiniNIC/PTP/Foreign Master 證據仍存在，但 Step 4 的「SoftPLL channel enabled、tag/TRR/servo correction path 開始工作」尚未成立，因此 **Step 4 NOT PASS**。

## Next Step

下一步做 source-level tagger/clock path audit，並以同一 fresh SOF 補齊 Step 1～3 runtime gate。若必須做 functional A/B，只能選一個與 tag event enable/clock path 直接相關的最小變因；在此之前不修改 PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。
