# EXP-WRPC-STEP4-QUALIFICATION-PREDICATE-AUDIT-20260825

## 實驗識別

- 日期：2026-08-25
- 實驗名稱：WAIT_STABLE_0 到 WAIT_EDGE predicate 與既有唯讀 counter 對照
- branch：`exp/step4-softpll-enable`
- source HEAD：`b040d1bc98843a1175ac32767a6b05ff944a1887`
- 相關 runtime evidence commit：`841d709`
- 類型：source audit + 既有 fresh-SOF read-only evidence review

## 目的與限制

本次只確認 reviewer 建議的下一個切點：實際 deglitch FSM 中，哪個條件使
`WAIT_STABLE_0 -> WAIT_EDGE`，以及目前是否已有完全相同條件的 read-only counter。

沒有修改 RTL、firmware、MIF、SoftPLL、PTP、WR signaling、PHY、DDMTD polarity、
threshold、PI、lock threshold、DCO 或 SI5340；沒有 compile、program 或寫入任何
Wishbone control register。

## Source-backed predicate

檔案：

```text
vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd
```

功能 FSM 的 `WAIT_STABLE_0` 分支是：

```vhdl
if clk_sampled /= '0' then
  stab_cntr <= (others => '0');
else
  stab_cntr <= stab_cntr + 1;
end if;

if stab_cntr = unsigned(r_deglitch_threshold_i) then
  state <= WAIT_EDGE;
end if;
```

目前既有 diagnostic process 使用完全相同的 transition predicate：

```vhdl
if state = WAIT_STABLE_0 and
   stab_cntr = unsigned(r_deglitch_threshold_i) then
  dbg_wait_edge_entry_count <= f_sat_inc(dbg_wait_edge_entry_count);
end if;
```

因此 `dbg_wait_edge_entry_count` 已經是 reviewer 所要求的
`PRE_WAIT_EDGE / qualification-complete` 邊界 counter；不應再新增第二個重複
counter，也不應改動 FSM 條件。

## Readout provenance

Wishbone source mapping：

- REF `dbg_wait_edge_entry_count`：`0x001002A0`
- FB `dbg_wait_edge_entry_count`：`0x001002A4`

目前 Tcl focused script 使用相同地址：

```text
scripts/jtag/read_step4_startup_focused.tcl
```

fresh HEAD 50-sample events raw log：

```text
docs/experiments/exp-step4-softpll-enable/raw/20260825_fresh_b040d1b/step4_events.log
```

該 fresh runtime window 的關鍵結果：

```text
Master:
  DMTD_REF_WAIT_EDGE_ENTRY delta = 0
  DMTD_FB_WAIT_EDGE_ENTRY  delta = 0
  DMTD_REF_GOT_EDGE_ENTRY  delta = 0
  DMTD_FB_GOT_EDGE_ENTRY   delta = 0
  DMTD_REF_ACCEPT          delta = 0
  DMTD_FB_ACCEPT           delta = 0

Slave:
  DMTD_REF_WAIT_EDGE_ENTRY delta = 0
  DMTD_FB_WAIT_EDGE_ENTRY  delta = 0
  DMTD_REF_GOT_EDGE_ENTRY  delta = 0
  DMTD_FB_GOT_EDGE_ENTRY   delta = 0
  DMTD_REF_ACCEPT           delta = 0
  DMTD_FB_ACCEPT            delta = 0
```

同一窗口中，兩板 native sampled、D0 transition、D0 stable-hit counters 均有
活動；50 samples 的 mailbox read 也全部 valid、無 timeout。因此目前 fresh
evidence 的 live boundary 可精確表示為：

```text
DMTD native / D0 / sampled activity
        ↓
WAIT_STABLE_0 qualification predicate
        ↓
WAIT_EDGE_ENTRY delta = 0
        ↓
GOT_EDGE / ACCEPT / TAG / TRR / IRQ / HELPER delta = 0
```

歷史 sticky `GOT_EDGE_HIGH_ABORT` 仍只能表示過去曾發生過，不代表本次 50×100 ms
window 持續發生。

## 結論

1. `WAIT_STABLE_0 -> WAIT_EDGE` 的實際 predicate 已由 source 確認。
2. 目前 branch 已有與 functional predicate 完全對齊的 read-only counter，且
   Wishbone/Tcl mapping 已存在；不需要新增 counter。
3. fresh runtime 的 `WAIT_EDGE_ENTRY=0` 是有效的 source-backed observation，
   但它尚未證明 root cause 是 deglitcher、timing、clock quality 或其他 functional
   原因。
4. Step 4 仍未通過；Step 2/3 regression 維持 PASS。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
ROOT_CAUSE = NOT_PROVEN
NEW_PROBE_REQUIRED = NO
```

## 下一步

先將這份 source audit 交由 reviewer 確認。若要繼續，必須由 reviewer 指定下一個
單一 functional/observability 變因；在此之前不修改 threshold、polarity、FSM、
SoftPLL 或 PHY 行為。
