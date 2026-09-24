# F4F Helper measurement source contract

Audit basis: source commit `e550e57d11493b18ff30728e3a295b63dc87cfa4`.

| Contract item | Source evidence | Address / ordering | F4F use |
|---|---|---|---|
| Epoch | `vendor/wrpc-sw/include/hw/wrc_diags_regs.h` and `vendor/wrpc-sw/dev/wdiags.c::wdiags_write_wr_spll_helper_measurement_debug` | `0x00100B00`; odd before payload writes, even after | Bracket every profile |
| Tag delta | Generated WDIAGS map and writer | `0x00100B04` | FULL only |
| Expected delta | Generated WDIAGS map and writer | `0x00100B08` | FULL only |
| Frequency error | Generated WDIAGS map and writer | `0x00100B0C` | FULL arithmetic check |
| Preclamp error | Generated WDIAGS map and writer | `0x00100B10` | FULL only |
| Helper error | Generated WDIAGS map and writer | `0x00100B14` | FULL and CORE |
| Producer update count | Generated WDIAGS map and writer | `0x00100B18` | FULL and CORE freshness |
| Helper output | Generated WDIAGS map and writer | `0x00100B1C` | FULL and CORE range check |
| DMTD ref accept count | Generated WDIAGS map and writer | `0x00100B20` | FULL only |
| DMTD FB accept count | Generated WDIAGS map and writer | `0x00100B24` | FULL only |
| Actual caller | `vendor/wrpc-sw/lib/task-diags.c::wrc_wr_diags` | Reads source measurement fields, then calls the writer | Confirms writer is passive transport |

The writer's payload sequence is one odd epoch, ten payload writes, one publish
barrier, and one even epoch commit. The CORE profile therefore uses only
`epoch → helper_error → update_count → helper_output → epoch`, which is covered
by the same epoch seqlock according to the source. CORE does not check or infer
the FULL tag/frequency equation, DMTD counters, or preclamp field.

The owner is intentionally `UNVERIFIED`: the current JTAG mailbox observation
does not provide a source-backed per-reader ownership token. A valid CORE row is
therefore a coherent read of the published diagnostic window, not proof of
exclusive ownership or a single-cycle causal snapshot.
