# 實驗紀錄：qualification abort sticky 觀測

## 實驗基本資料

- Experiment ID：`EXP-WRPC-QUAL-ABORT-20260825`
- 日期：2026-08-25
- Branch：`exp/step4-softpll-enable`
- Git commit：`856ebbbec56bfe33a78667baea047dcdfdb60637`
- 實驗名稱：`GOT_EDGE -> high qualification abort` 唯讀診斷
- 目的：區分 DMTD deglitcher 是尚未進入高電位 qualification，還是已進入後又中止，並確認 Step 2/3 regression 沒有被本次診斷修改破壞。

## 與前一版相比的唯一變因

只把既有 DMTD RTL 內部已存在的 high qualification abort counter，以唯讀方式暴露到既有 `SPLL_DMTD_STATE` 未使用的 bit：

- bit31：REF high qualification abort seen
- bit30：FB high qualification abort seen
- REF/FB abort counter 的累加條件與 DMTD FSM 沒有修改
- 原有 state、reset、bucket、threshold、GOT_EDGE sticky bit 保持不變

本次沒有修改 DMTD threshold、polarity、FSM transition、DMTD 演算法、SoftPLL 演算法、PI gain、lock threshold、DCO、SI5340 或 firmware functional flow。

## Build provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA256：`d7255141a6a86d087d8a48bfef4e328685a52c0bc92ca5a1eb10d20dd21aab12`
- Slave MIF SHA256：`dfda7dc95d59ddc36333b6384ac8bef453e567f00d2564b67f0741869803548f`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`4470f1cc70a1322dd49d1ddbdbb90069d75244b0ab3c0d3d49c4fec20bb400eb`
- Slave SOF SHA256：`dc40cad155ccb2eafc22775ee010edb91ca5a8260a713f6436e04b86de8d324b`
- Build 結果：Master/Slave fresh clean Quartus compile passed；兩份 build script 都回報 `timing_closed=NO`。

## 燒錄證據

- Master cable：`DE5 [1-11.1]`
- Master programmer checksum：`0x30B0BD3E`
- Slave cable：`DE5 [1-11.2]`
- Slave programmer checksum：`0x30B377BD`
- 兩片 JTAG ID：`0x02E660DD`
- 結果：兩片皆 `Configuration succeeded`，Quartus Programmer 回報 0 errors、0 warnings。
- 燒錄後等待：60 秒。
- 本次沒有發生 stall、connection abort 或需要實體重啟的情況。

## Step 2 / Step 3 regression

使用 `scripts/jtag/read_wr_handshake_focused.tcl 25 500 25`，每片 25 個樣本、樣本間隔 500 ms。

| 項目 | Master | Slave | 結論 |
|---|---:|---:|---|
| valid samples | 25/25 | 25/25 | 讀值有效 |
| MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` | PASS |
| MODE | 2 | 3 | PASS |
| PTP | 6 | 9 | PASS |
| PTP traffic | RX/TX 持續增加 | RX/TX 持續增加 | PASS |
| MiniNIC traffic | TX/RX 持續增加 | TX/RX 持續增加 | PASS |
| RXERR | 0 且未增加 | 0 且未增加 | PASS |
| FOREIGN | 不適用 | `1/0` | PASS |
| Parent flags | 不適用 | `1/0/1` | PASS |
| WR RX/TX message | `0x1000/0x1001` | `0x1001/0x1000` | PASS |
| LOCK_ENABLE | 不適用 | 4 | PASS |

Focused gate 結果：

```text
Master STEP2_REGRESSION=PASS
Slave  STEP2_REGRESSION=PASS STEP3_REGRESSION=PASS
```

Slave 有少數樣本的 current state / WR message 讀值與其他 handshake 欄位不一致；focused script 將其保留為 state/read inconsistency，而不是因單一 mailbox snapshot 宣稱 Step 3 hardware failure。Step 2/3 的 repeated accepted evidence 仍滿足本輪 regression gate。

## Step 4 觀測結果

使用 `scripts/jtag/read_step4_startup_focused.tcl 10 500`，每片 10 個樣本、樣本間隔 500 ms。

### Master

- `SPLL_STATE=0x00020009`
- `RCER=0`
- `PSTAT.locked=0`；此欄位屬 Step 5，不作為本輪 Step 4 gate
- REF/FB sampled DMTD event delta：`666252147` / `665977381`
- REF `QUAL_REACHED_8_COUNT`：由 `0x001C0001` 到 `0x001E0001`，上半部計數增加 2
- FB `QUAL_REACHED_8_COUNT`：`0 -> 0`
- REF/FB high qualification maximum stable count：`8 / 7`
- REF/FB `GOT_EDGE` sticky：`1 / 1`
- REF/FB high qualification abort sticky：`1 / 1`
- REF/FB DMTD accept delta：`0 / 0`
- TAG、TRR、IRQ、helper、state transition：未見可接受的持續 activity
- Step 4 boundary：`QUALIFICATION_PROGRESS_TO_DEGLITCH_ACCEPT`

這表示 Master 至少曾抵達 REF 第 8 個 high sample，且之後仍出現 abort evidence；但沒有證明進入 DMTD accept 或下游 SoftPLL event pipeline。

### Slave

- `SPLL_STATE=0x00030009`
- `RCER=1`
- `PSTAT.locked=0`；此欄位屬 Step 5，不作為本輪 Step 4 gate
- REF/FB sampled DMTD event delta：`666989440` / `668645820`
- REF `QUAL_REACHED_8_COUNT`：`1 -> 1`
- FB `QUAL_REACHED_8_COUNT`：`0 -> 0`
- REF/FB high qualification maximum stable count：`2 / 1`
- REF/FB `GOT_EDGE` sticky：`1 / 1`
- REF/FB high qualification abort sticky：`1 / 1`
- REF/FB DMTD accept delta：`0 / 0`
- TAG grant delta：2；TAG valid 讀值出現異常大 delta，但與 downstream DMTD accept、TRR、last-tics 不一致，列為 snapshot/回繞疑點，不作為有效 SoftPLL activity
- TRR、IRQ、helper、state transition：未見持續 activity
- Step 4 boundary：`QUALIFICATION_ABORT_AFTER_GOT_EDGE`

這表示 Slave 看見 edge，但高電位 qualification 最多只到 2/1 個 sample 就中止；目前沒有證明完成 accept 或進入 helper。

## Step 4 判定

```text
STEP4_RESULT = NOT_PASS
FIRST_OBSERVED_BLOCKER = GOT_EDGE -> high qualification abort / no sustained accept
```

Step 4 的「SoftPLL channel enabled」部分在 Slave 有 `RCER=1` 的證據；但 Step 4 完整 gate 還要求 DMTD/tag/TRR/servo downstream 有持續活動，目前不成立，因此不能標示 Step 4 PASS。

## Raw evidence

- Step 2/3 log：[`step23_abort_seen_856ebbb.log`](raw/EXP-WRPC-QUAL-ABORT-20260825/step23_abort_seen_856ebbb.log)
  - SHA256：`BD3686C20E1344226FEA6C22CBADB8A9B78F55B2AEC8D9F33BD17B20E88ACDEE`
- Step 4 log：[`step4_abort_seen_856ebbb.log`](raw/EXP-WRPC-QUAL-ABORT-20260825/step4_abort_seen_856ebbb.log)
  - SHA256：`9B8EA350B7F04478772D1F47BB3E9EB218E9D8DED6C019C7FCCC559735C44E2E`

兩份 log 的結尾均包含：

```text
Evaluation of Tcl script ... was successful
Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
SCRIPT_RC step23=0 step4=0
```

## Observation 與結論

本次是由 exact Git commit `856ebbbec56bfe33a78667baea047dcdfdb60637` 產生 fresh MIF、clean Quartus compile、fresh SOF、雙板 program，再執行 read-only JTAG regression。Step 2 與 Step 3 的 packet/parent/handshake evidence 重新通過，因此 regression barrier 沒有阻擋後續 Step 4 研究。

新的 sticky abort 觀測比前一輪更進一步：

- Master：REF 曾到達 qualification-8，但仍未 accept，並且看到 high qualification abort。
- Slave：REF/FB 最高只到 2/1，便看到 high qualification abort。
- 兩片都沒有可靠的 sustained DMTD accept、TRR write、helper update 證據。

這些證據只支持「目前卡在 GOT_EDGE 後的 qualification/accept 邊界」，不能單獨證明是 polarity、threshold、時鐘品質或某一段 functional RTL 的根因。Slave 的部分 counter 讀值有跨暫存器 snapshot、回繞或 CDC 讀取疑點，因此不能把單一異常 delta 當成硬體功能失敗。

## Regression barrier 與下一步

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
```

下一步仍遵守一次一個變因：先請 reviewer 依本次 qualification abort 證據決定下一個 read-only/source audit；在沒有確認證據前，不修改 threshold、polarity、FSM、SoftPLL 演算法、PI gain、lock threshold、DCO 或 SI5340 行為。

