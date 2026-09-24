# EXP-WRPC-STEP4-HIGH-QUAL-ABORT-MAP-20260826

## 實驗基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：`EXP-WRPC-STEP4-HIGH-QUAL-ABORT-MAP-20260826`
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- FPGA/build commit：`b118aae9af586777cd4bf9691f2732dd46c8933d`
- Quartus：17.0.0 Build 595
- 本輪目的：將 current HEAD 的 high-qualification abort read-only mapping 以 fresh SOF 實際燒錄兩板，重新建立 Step2/3 barrier，並在同一輪觀察 Step4 event boundary。

分支2的 ChatGPT conversation 目前無法由本機 thread connector 讀取（工具回報 `No Codex thread found`）；本輪起始依使用者提供的 cached preview 中最新可見建議執行：current HEAD fresh build/program，然後讀取 `HIGH_QUAL_ABORT_COUNT`、`GOT_EDGE_ENTRY` 與 `ACCEPT`。這個 connector 限制與 cached context 不當作新的分支回覆。

## Source / Git 狀態

current HEAD 已包含 `a367d30` 的 high-qualification abort read-only mapping；source audit 顯示不需要再新增 RTL、功能參數或 probe，因此本輪沒有額外 source 修改。執行：

```text
git push origin exp/step4-softpll-enable
Everything up-to-date
```

## Fresh build provenance

| 項目 | Master | Slave |
|---|---|---|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| MIF SHA256 | `0b49f2fde9f7b4195c097c124b5bc0b9d98ef206a2f4ae064b588d7033a56b35` | `762ac981230951261ccb67169eb92d49dab865381db8077a21d7f5e14cbf34b8` |
| SOF SHA256 | `191c749e0aba75638bda387cbbd65ef13f46c5ab16460c982a5f6db0086bdabb` | `f2acb0dd783cceee0398e02634ac8d0e5cee7fc350b6deb8cebd571f56646849` |
| Programmer checksum | `0x30B40324` | `0x30B3CD7B` |
| Quartus compile | Full Compilation successful | Full Compilation successful |
| Timing | `TIMING_CLOSED=NO`, worst setup `-0.152 ns` | `TIMING_CLOSED=NO`, worst setup `-0.160 ns` |

兩個 build script 均完成 clean compile，且 SOF 存在。Timing 未 closed，保留為工程風險，不與 Step4 runtime gate 混為一談。

## Programming evidence

- Master：cable `DE5 [1-11.1]`，`Configuration succeeded`，0 errors / 0 warnings，checksum `0x30B40324`。
- Slave：cable `DE5 [1-11.2]`，`Configuration succeeded`，0 errors / 0 warnings，checksum `0x30B3CD7B`。

因此本輪已建立 current HEAD → fresh SOF → two-board programming provenance。

## Step2 / Step3 barrier

`read_wr_handshake_focused.tcl 30 1000`：

```text
Master: valid=30 invalid=0 counter_decreased=0 PTP_TX_DELTA=161 STEP2=PASS
Slave : valid=30 invalid=0 counter_decreased=0 PTP_TX_DELTA=19 STEP2=PASS STEP3=PASS
Slave : POST_STEP3_LOCK_STAGE=TIMEOUT STATE_EVIDENCE=READ_INCONSISTENT
```

因此本輪的 repeated Step2/3 evidence 足以允許繼續觀察 Step4，但不能把 Slave current state 解讀成已完成 WR lock。`read_step23_register_reliability.tcl 30 500 all` 於 JTAG `do_select` 等待超過 7 分鐘，最後以 return code `143` 終止；該 partial log 不作為 PASS 證據。第一支 handshake gate 的 Quartus SignalTap 執行則為 0 errors / 0 warnings。

## Step4 focused observation

命令：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 20 500 all --raw
```

### Master（DE5 [1-11.1]）

```text
DMTD native delta       = 1637863045, result=VALID
WAIT_STABLE0 max        = REF 62 / FB 15, threshold=1000
ACCEPT                  = REF 0 / FB 0
GOT_EDGE_ENTRY delta    = REF 0 / FB 0
HIGH_QUAL_ABORT delta   = REF 812786904 / FB 612904636
TAG/TRR/IRQ/HELPER      = 0 / 0 / 0 / 0
EVENT_BOUNDARY          = QUALIFICATION_ABORT_AFTER_GOT_EDGE
```

### Slave（DE5 [1-11.2]）

```text
DMTD native delta       = 1597546480, result=VALID
WAIT_STABLE0 max        = REF 0 / FB 0, threshold=1000
HIGH_QUAL_MAX_STAB      = REF 2 / FB 1
ACCEPT                  = REF 0 / FB 0
GOT_EDGE_ENTRY delta    = REF 0 / FB 0
HIGH_QUAL_ABORT delta   = REF 792152615 / FB 793673564
TAG/TRR/IRQ/HELPER      = 0 / 0 / 0 / 0
EVENT_BOUNDARY          = QUALIFICATION_ABORT_AFTER_GOT_EDGE
```

兩板前級 DMTD native activity 都有效，但 functional `WAIT_STABLE_0` max 都遠低於 threshold，且 downstream event chain 沒有跨過 `ACCEPT`。同時 high-abort readback 回報非零 modulo delta，但 `GOT_EDGE_ENTRY delta=0`，且 Slave 的 sampled counter 有 decreased/reset warning；因此這輪證明了 blocker 仍在 qualification → ACCEPT 邊界，卻不能把 high-abort counter 與 GOT_EDGE entry 建立成完全一致的 live event-rate 證據。

Dashboard 也觀察到：

```text
SPLL_TRR_WRITE_COUNT = delta 0
WRPC_SPLL_TRR_POP_COUNT = delta 0
WDIAGS_HELPER_UPDATE_COUNT = delta 0
SPLL_TAG_VALID_COUNT = delta 0
```

所以本輪仍不能驗證 CPU POP TRR；更不能把 `TRR_POP=0` 解讀成 CPU 讀取失敗，因為上游沒有新的 TRR event。

## 正式判定

```text
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS with STATE_EVIDENCE=READ_INCONSISTENT caveat
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
ROOT_CAUSE       = NOT_PROVEN
TRR_CPU_READ     = NOT_RUNTIME_VERIFIED
```

這輪已排除「只是未知舊 image」的主要疑問，但沒有達成 Step4。下一輪應先請分支2 review 這次 fresh evidence，特別是 high-abort counter 非零、GOT_EDGE entry delta 為零，以及 reliability JTAG timeout 的矛盾；在收到新的建議前不自行改 functional FSM、threshold、polarity、SoftPLL、PI、DCO、SI5340 或 PHY。

## 原始證據

本輪 raw logs 與 build provenance 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-QUAL-ABORT-MAP-20260826/`

包含：

- `observation_meta.txt`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `build_jtag_master.log`
- `build_jtag_slave.log`
- `step123_handshake.log`
- `step23_reliability.log`
- `step4_focused.log`
- `dashboard.log`
