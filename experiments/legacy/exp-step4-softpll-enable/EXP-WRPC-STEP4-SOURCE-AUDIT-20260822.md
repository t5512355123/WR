# EXP-WRPC-STEP4-SOURCE-AUDIT-20260822

## 審查範圍

- 日期：2026-08-22
- branch：`exp/step4-softpll-enable`
- source HEAD：`0cc755bd53914e2a3d449c3c8643b1f95c05abd5`
- 類型：read-only source audit；沒有 compile、program 或修改 FPGA 行為。

## WDIAGS_TEMP 的真正語意

`WDIAGS_TEMP (0x00100A4C)` 在 DE5a 無溫度感測器的 build 中被重用為 WR state shadow：

- `vendor/wrpc-sw/dev/wdiags.c`：`wdiags_write_wr_state_debug()` 將值寫入 `WRC_DIAGS_WDIAG_TEMP`。
- `vendor/wrpc-sw/lib/task-diags.c`：當 `!HAS_TEMP_SENSORS` 時，每次 diagnostic refresh 組合 `wr_state_debug`。
- 其內容包含：
  - bit 0：`wrModeOn`
  - bit 1：`parentWrModeOn`
  - bit 2：`calibrated`
  - bit 3：`parentIsWRnode`
  - bit 4：`parentCalibrated`
  - bits 7:5：`wrConfig`
  - bits 10:8：`parentWrConfig`
  - bits 14:11：`wrp->state`
  - bits 18:15：`wrp->next_state`
  - bits 20:19：`parentDetection`
  - bits 23:21：`wrMode`
  - bits 31:24：`0xA0` tag

因此 `WDIAGS_TEMP` 是 software diagnostic refresh 的 shadow，不是獨立、sticky 的硬體 current-state register。它可以在 WR handshake 曾經完成後，因後續 `wr_handshake_fail()` 或 recovery 將 live `wrp->state` 寫回 `WRS_IDLE`；這不會抹掉同一輪已讀到的 `LOCK_ENABLE=4` 與 accepted signaling evidence。

## DMTD event chain source mapping

`vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd` 的功能路徑是：

```text
clk_sampled
  -> p_deglitch / stab_cntr
  -> new_edge_p_dmtdclk
  -> gc_pulse_synchronizer2
  -> new_edge_p_sysclk
  -> tag_stb_p1_o / dbg_event_sys_o
```

本次 fresh 30-sample 讀值顯示 Slave threshold sticky 已為 1，但 deglitch accept counter 與下游 tag/TRR/IRQ/helper counters 仍為 0。因此目前證據只支持：

```text
deglitch qualification 曾到達 threshold
```

不支持：

```text
new_edge_p_dmtdclk 已持續產生
new_edge_p_sysclk 已成功跨 CDC
tagger/servo 已收到 event
```

`DMTD_REF_SEEN/FB_SEEN` 是 packed/低位寬觀測欄位，存在 wrap、非 atomic snapshot 與 decrease ambiguity；不能取代完整 event counter 或 sticky pulse evidence。

## 審查結論

- `WDIAGS_TEMP=WRS_IDLE` 與 `LOCK_ENABLE=4` 不必然矛盾；前者是目前 diagnostic refresh shadow，後者是曾經進入 locking enable 的證據。
- Step 3 focused evidence 可維持 PASS，另列 `POST_STEP3_CURRENT_STATE=WRS_IDLE` 與 `STATE_EVIDENCE=READ_INCONSISTENT`。
- Step 4 仍為 `NOT_PASS`。
- 下一個單一 diagnostic 變因應觀察 `new_edge_p_dmtdclk` 與 `new_edge_p_sysclk` 的 sticky/count evidence；不能修改 deglitch threshold、CDC、SoftPLL 或 servo 功能。
