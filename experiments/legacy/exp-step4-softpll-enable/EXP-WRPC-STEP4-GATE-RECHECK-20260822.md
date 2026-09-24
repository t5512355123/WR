# EXP-WRPC-STEP4-GATE-RECHECK-20260822

## 實驗基本資料

- 實驗名稱：Step 3 LOCK delivery 與 Step 4 event-chain 唯讀複核
- 日期：2026-08-22
- Git branch：`exp/step4-softpll-enable`
- pain runtime checkout：`5074e0e44cc2ef16c993489ab092e28dbb0b0a99`
- 實驗目的：在不重新 program、不 compile、不寫 runtime control register 的情況下，確認 Step 3 的正向 handshake evidence 是否仍存在，並重新觀察 Step 4 的 DMTD 到 downstream chain。
- 唯一操作變因：無硬體或 firmware 變更；只新增兩次 read-only JTAG 觀測窗口。

## 操作與原始證據

### Step 3 LOCK delivery

執行：

`quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl 30 500 step3`

結果：exit code `0`，Quartus SignalTap II `0 errors, 0 warnings`。

原始 log：`raw/regression_step3_delivery_recheck_5074e0e_20260822.log`

Slave 30/30 valid samples：

- `FOREIGN_META=03000001`
- `WR_RX_SIGNAL=10010001`：accepted RX message `0x1001`，count 1
- `WR_TX_SIGNAL=10000001`：TX message `0x1000`，count 1
- `LOCK_ENABLE=00000004`
- `WR_SIGNAL_REJECT=00000000`
- `WR_FAILURE_DEBUG=02020001`：30/30 保留 `WRS_S_LOCK` failure-state evidence
- `WDIAGS_TEMP=A000035C`：30/30 的 live shadow state 為 idle
- focused result：`STEP3_INDEPENDENT=PASS`
- post-stage：`last_fail_state=WRS_S_LOCK`、`current_state=WRS_IDLE`

這組結果支持：Step 3 的 LOCK delivery 與 `locking_enable()` evidence 確實存在；目前 live state 已位於後續 recovery/idle。`WRS_IDLE` 不能單獨否定正向 handshake evidence。

### Step 4 event-chain

執行：

`quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_step4_event_chain.tcl 5000`

結果：exit code `0`，Quartus SignalTap II `0 errors, 0 warnings`。

原始 log：`raw/regression_step4_event_chain_recheck_5074e0e_20260822.log`

5 秒前後比較：

| 欄位 | Master | Slave |
|---|---:|---:|
| `LOCK_ENABLE` | `0` | `4` |
| `RCER` | `0` | `1` |
| `OCER` | `1` | `1` |
| `DMTD_REF_EVENTS` delta | `0` | `0` |
| `DMTD_FB_EVENTS` delta | `0` | `0` |
| `TAG_PENDING/GRANT/VALID` delta | `0/0/0` | `0/0/0` |
| `TRR_WRITE` delta | `0` | `0` |
| `IRQ_COUNT` delta | `0` | `0` |
| `HELPER_UPDATE_COUNT` delta | `0` | `0` |
| `SPLL_DMTD_STATE` | `0xA` | `0x8` |

## 判讀

本次不把 Master 的 `RCER=0` 當成 Step 4 failure，因為 Master role 的 Step 4 startup criteria 不等同 Slave handoff criteria。對 Slave 而言，`RCER=1` 與 `LOCK_ENABLE=4` 已證明 channel enable 曾發生，但 5 秒內未觀察到 DMTD event counter 或 downstream tag/TRR/helper activity。

目前 source-backed 的待釐清邊界是：

`clk_sampled -> deglitch stability qualification -> new_edge_p_dmtdclk -> post-CDC event`

現有 2-bit `SPLL_DMTD_STATE` 只能顯示狀態，不足以知道 `stab_cntr` 是否正在累積或是否達到 threshold；新增的 packed low-15 diagnostic counter 又可能多圈 wrap。因此本次只確認「下游沒有 activity」，不宣稱 SoftPLL 演算法或 DDMTD polarity 是根因。

## Gate 結果

- `STEP1_REGRESSION=PASS`：沿用同一份 fresh SOF 的 PHY/link evidence。
- `STEP2_REGRESSION=PASS`：Step 3 delivery script 同時讀到正確 role/foreign/PTP path，且 counters valid。
- `STEP3_REGRESSION=PASS_WITH_POST_STAGE_TIMEOUT`：30/30 valid，LOCK/SLAVE_PRESENT/LOCK_ENABLE evidence 存在，live state 後續為 idle。
- `STEP4_READONLY_OBSERVATION=INCONCLUSIVE_AT_DEGLITCH_BOUNDARY`。
- `STEP4_FUNCTIONAL_CHANGE_ALLOWED=NO`。

## Next Step

只新增 read-only DMTD deglitch stability observability：將 `stab_cntr` 的同步 shadow（必要時加 threshold-reached sticky bit）接到既有 diagnostics，不改變 `p_deglitch` 的條件、threshold、reset、state transition、tag pulse 或 SoftPLL arbitration。完成後才重新 fresh compile/program，並先重跑 Step 1/2/3，再測 Step 4。
