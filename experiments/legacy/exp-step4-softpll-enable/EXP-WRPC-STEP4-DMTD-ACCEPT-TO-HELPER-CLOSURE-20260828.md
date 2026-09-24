# EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828

## 結論

**STEP 4 = PASS（Master active path；Slave passive control）**

這個結論只採用最後一次 fresh reprogram 後、符合 dispatch gate 的觀測窗。Master 明確出現：

```text
CLOSURE_DISPATCH_CONFIRMED
COMMAND_STAGE=9
PERSIST_MODE_MASTER_STAGE=5
CLOSURE_CLASSIFICATION result=STEP4_EVENT_CHAIN_PASS
```

因此可確認：

```text
DMTD accepted event
→ TAG_VALID
→ TRR write
→ TRR pop
→ IRQ
→ helper update
```

已在同一個 Master measurement window 內持續發生；static-FSM false-restart blocker 的驗證條件也成立。Step 5 的 PLL lock criteria 不在本實驗範圍內。

## 實驗範圍與 provenance

- Branch：`exp/step4-softpll-enable`
- Firmware/FPGA image source：`dacb032bd1cce2b982907dedf067df76ffebc1f9`
- Closure reader source：`567b50e`
- 最終 reader 只增加可設定的 dispatch observation timeout；沒有修改 parser、VUART、shell scheduling、mode handler、SoftPLL、DMTD、reset tree 或任何 functional RTL/firmware。
- Final run 前重新 program：Master cable `DE5 [1-11.1]`、Slave cable `DE5 [1-11.2]`；兩者均為 1 device configured、0 errors、0 warnings。
- 固定觀測窗：10 s baseline → Master 單次 `mode master\n` → 等待 dispatch confirmation → 30 s measurement → 10 s post；Slave 不注入 stimulus。

## Source audit

Primary accepted-event evidence 使用 WR SoftPLL diagnostic event counters，而不是 raw sampled-transition counter：

- `DMTD_REF_EVENTS`：WB `0x00100298`
- `DMTD_FB_EVENTS`：WB `0x0010029C`
- source：`vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd` 的 `p_diag_tag_events`
- `dmtd_event_sys` 來自 `dmtd_with_deglitcher.vhd` 的 deglitch/qualification path；同一 accepted edge 供 TAG path 使用。

Chain counters：

- `TAG_VALID_COUNT`：`0x00100284`
- `TRR_WRITE_COUNT`：`0x00100288`
- `TRR_POP_COUNT`：`0x00100B54`
- `IRQ_COUNT`：`0x00100AEC`
- `HELPER_UPDATE_COUNT`：`0x00100B18`

Reset/health evidence：boot generation、CPU reset、WR-core reset、SI config drop，以及 live reset/status fields 均同步取樣。

## Final Master measurement evidence

| Counter | Δ during 30 s measurement |
|---|---:|
| DMTD accepted event（REF + FB） | 236,262 |
| DMTD REF event | 116,337 |
| DMTD FB event | 119,925 |
| DMTD REF qualified | 116,336 |
| DMTD FB qualified | 119,924 |
| TAG_VALID | 119,925 |
| TRR write | 119,924 |
| TRR pop | 119,101 |
| IRQ | 119,101 |
| helper update | 119,101 |

Reset/re-entry deltas：

```text
BOOT_GENERATION_DELTA      = 0
CPU_RESET_COUNT_DELTA      = 0
WR_CORE_RESET_COUNT_DELTA  = 0
SI_CONFIG_DROP_COUNT_DELTA = 0
```

Correlation ratios from the same window：

```text
TAG_PER_DMTD          = 0.507593
TRR_WRITE_PER_TAG     = 0.999992
TRR_POP_PER_TRR_WRITE = 0.993137
IRQ_PER_TRR_POP       = 1.000000
HELPER_PER_IRQ        = 1.000000
```

The small TRR write/pop boundary skew is explainable by the counter window boundary: the following 10 s post window continues to drain the chain (`TRR_POP=40,001`, `IRQ=40,000`, `HELPER=40,001`) while all reset/re-entry deltas remain zero. The decisive downstream boundary is not zero or stalled; it is active with one-for-one IRQ/helper progression.

## Slave control

Slave was intentionally passive. Its measurement result is `PASSIVE_CONTROL`, with no TAG/TRR/IRQ/helper increments and no reset deltas. It is not used as an independent Step 4 active-pass claim.

## Earlier attempts retained for audit

- First reader run: rejected as invalid because its fixed 10 s dispatch wait expired before stage 5; raw result was `INVALID_NO_VALID_MODE_MASTER_DISPATCH`.
- Second run without reprogram: rejected because the Master ready gate was not stable after the previous run.
- The final run below was preceded by fresh reprogram and uses the extended 30 s dispatch wait; it is the only run used for the PASS conclusion.

## Raw evidence

- [Final closure reader log](raw/EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828-fresh/closure_reader.log)
- [Final Master build info](raw/EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828-fresh/build_info_jtag_master.txt)
- [Final Slave build info](raw/EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828-fresh/build_info_jtag_slave.txt)
- [Final programming summary](raw/EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828-fresh/programming_summary.txt)
- [Rejected first-run log](raw/EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828-first/closure_reader.log)
- [Rejected no-reprogram rerun log](raw/EXP-WRPC-STEP4-DMTD-ACCEPT-TO-HELPER-CLOSURE-20260828-rerun/closure_reader.log)
