# 實驗紀錄：GOT_EDGE 後 qualification progress 觀測

## 實驗基本資料

- Experiment ID：EXP-WRPC-QUAL-PROGRESS-20260825
- 日期：2026-08-25
- Branch：`exp/step4-softpll-enable`
- Git commit：`a80baf9cce0cb6f589fa06e46c9dcb92185d1497`
- 實驗名稱：`GOT_EDGE -> qualification progress` 唯讀診斷
- 目的：確認 DMTD deglitcher 在 `GOT_EDGE` 之後，是否真的累積到 8 個連續 HIGH sample，並繼續進入 accept。

## 與前一版相比的唯一變因

新增唯讀診斷計數器 `QUAL_REACHED_8_COUNT`：

- REF 位址：`0x00100268` 的 read-side upper 16 bits
- FB 位址：`0x0010026C` 的 read-side upper 16 bits
- 計數條件：既有 `GOT_EDGE` 狀態下，`clk_sampled` 維持 HIGH 且 `stab_cntr=7`，代表到達第 8 個連續 HIGH sample。
- 計數器為飽和計數器，只用來觀測 qualification progress。

本次沒有修改 deglitch threshold、polarity、FSM transition、DMTD 演算法、SoftPLL 演算法、PI gain、lock threshold、DCO、SI5340 或 firmware functional flow。

## Build provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA256：`ac21d4c1c6d712c1407b961ccb16cfef9c47a3e4d26cfb8d91e22656fa31f23a`
- Slave MIF SHA256：`5bba7afde7ac0aaba946ea20e6ade1017cf15a861b465760a5bbd4c78545d490`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`f4a1b12d8f5a23dd7d369a822d0aa336bd021083a0543c5d7f1c2ed2098abae8`
- Slave SOF SHA256：`fb24301b480cca557ad5166138038b8f0d99b431e49760babc359f61a6ed4def`
- Build 結果：Master/Slave fresh clean Quartus compile passed；腳本回報 `timing_closed=NO`。

## 燒錄證據

- Master cable：`DE5 [1-11.1]`
- Master programmer checksum：`0x30AE51A4`
- Slave cable：`DE5 [1-11.2]`
- Slave programmer checksum：`0x30B467AC`
- 兩片 JTAG ID：`0x02E660DD`
- 結果：兩片皆 `Configuration succeeded`，且 programmer 回報 0 errors、0 warnings。
- 燒錄後等待：60 秒。

## Step 2 / Step 3 regression

使用 `scripts/jtag/read_wr_handshake_focused.tcl 25 500 25`，25 個樣本、每次間隔 500 ms。

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

Focused gate 輸出：

```text
Master STEP2_REGRESSION=PASS
Slave  STEP2_REGRESSION=PASS STEP3_REGRESSION=PASS
Slave  STATE_EVIDENCE=READ_INCONSISTENT
```

Slave 的 current state 在 25 個樣本中仍為 idle，而其他 handshake 欄位穩定成立；依既定規則將此列為 `READ_INCONSISTENT`，不能單獨宣稱 Step 3 hardware failure。Step 2/3 的其他 repeated evidence 均通過。

## Step 4 觀測結果

使用 `scripts/jtag/read_step4_startup_focused.tcl 10 500`，10 個樣本、每次間隔 500 ms。

### Master

- `GOT_EDGE`：REF/FB 都看見，`ref_got_edge_seen=1`、`fb_got_edge_seen=1`
- `QUAL_REACHED_8_COUNT`：REF `1 -> 1`，FB `0 -> 0`
- `DMTD_REF_ACCEPT` / `DMTD_FB_ACCEPT`：delta=0
- TAG pending/grant/valid、TRR write/pop、IRQ、helper update、state transition：delta=0
- `RCER=0`
- Step 4 boundary：`GOT_EDGE_TO_QUALIFICATION_PROGRESS`

### Slave

- `GOT_EDGE`：REF/FB 都看見，`ref_got_edge_seen=1`、`fb_got_edge_seen=1`
- `QUAL_REACHED_8_COUNT`：REF `1 -> 1`，FB `0 -> 0`
- `DMTD_REF_ACCEPT` / `DMTD_FB_ACCEPT`：delta=0
- TAG pending/grant/valid、TRR write/pop、IRQ、helper update、state transition：delta=0
- `RCER=1`
- `SPLL_STATE=0x00030009`
- `PSTAT.locked=0`；此欄位屬 Step 5，不作為本次 Step 4 gate
- Step 4 boundary：`GOT_EDGE_TO_QUALIFICATION_PROGRESS`

### Step 4 判定

```text
STEP4_RESULT = NOT_PASS
FIRST OBSERVED BLOCKER = GOT_EDGE -> qualification progress
```

新計數器沒有持續增加，表示目前證據仍只支持「進入 GOT_EDGE」，不支持已完成 8-sample qualification，更不支持後續 accept、TAG、TRR 或 helper activity。

## Raw evidence

- Step 2/3 log：[`step23_qual_progress_a80baf9.log`](raw/EXP-WRPC-QUAL-PROGRESS-20260825/step23_qual_progress_a80baf9.log)
  - SHA256：`594EAADF4738B8A5DDC82DBB92FCF0D9FC242D7720359EF4E3E999E6DBB8B63A`
- Step 4 log：[`step4_qual_progress_a80baf9.log`](raw/EXP-WRPC-QUAL-PROGRESS-20260825/step4_qual_progress_a80baf9.log)
  - SHA256：`005A20A3D4349A0205107E941D90552571C0CADCEB31AF7EB5C15ED025DC9795`

## Observation 與結論

本次 fresh source、fresh MIF、fresh clean Quartus compile、fresh SOF、雙板 program 與 read-only runtime evidence 均可追溯到 `a80baf9`。Step 2 及 Step 3 的 packet/parent/handshake evidence 重新通過；因此 regression barrier 沒有阻擋 Step 4 研究。

Step 4 尚未通過。證據把問題進一步收斂在 `GOT_EDGE` 後的 qualification progress，而不是 JTAG timeout、PTP packet path 或 Step 2/3 regression。這仍是觀測到的第一個 blocker，不等於已證明某一個 RTL 根因。

## Next Step

維持一個變因原則。下一輪先做 read-only qualification attempt/progress 的更細觀測，確認是：

1. high qualification counter 根本沒有到達 8；或
2. 到達 8 但 counter read-side 沒有正確取回；或
3. qualification 完成後 accept 條件仍被其他 source-backed 條件阻擋。

在完成上述區分前，不修改 threshold、polarity、FSM、SoftPLL 演算法或任何 DCO/SI5340 行為。

