# EXP-S5-F4I source-coherence audit

## Scope

This audit is the offline prerequisite for
`EXP-S5-F4I-MAIN-FREQUENCY-PHASE-HANDOFF-AUDIT-20260916`.  It is an
observability/replay audit only.  No production C, RTL, PI parameter, lock
threshold, timeout, bootstrap, arbitration, mailbox, reset, or image-control
source is modified by F4I.

The question is deliberately narrower than Step5:

> When the published Main frame says frequency lock is present, does the
> observed Main update stream show a stable handoff to the phase-error path,
> or does residual frequency error coincide with repeated frequency-domain
> re-entry?

## Producer path and source locations

The following source facts are verified in the current branch:

| Source | Location | Finding |
|---|---:|---|
| `vendor/wrpc-sw/include/spll_defs.h` | 28, 33 | `TAG_BITS=22`; `HPLL_N=14`. |
| `vendor/wrpc-sw/softpll/spll_main.c` | 216-225 | `update_dtag_dt()` performs the 22-bit tag-delta wrap handling. |
| `vendor/wrpc-sw/softpll/spll_main.c` | 358-390 | `freq_error=dout_dt-dref_dt`; unlocked Main uses `-freq_prelock_gain_boost*freq_error`; locked Main uses wrapped phase error. |
| `vendor/wrpc-sw/softpll/spll_main.c` | 396, 442-455 | PI update runs before phase lock-detector update; phase detector is updated only after `freq_ld.locked`. |
| `vendor/wrpc-sw/softpll/spll_common.c` | 17-65 | PI trace epoch brackets the trace fields. `trace_x`, output, and clamp fields are published before the even epoch. |
| `vendor/wrpc-sw/softpll/softpll_ng.c` | 300-328 | Helper is updated first; `mpll_update()` is called only when Helper is locked. |
| `vendor/wrpc-sw/softpll/softpll_ng.c` | 342 onward | The IRQ drains TRR and invokes sequencing/update loops in the interrupt context. |
| `vendor/wrpc-sw/lib/task-diags.c` | 26, 103 | Diagnostic task refreshes at `TICS_PER_SECOND/10`; it is a slower task, not the control iteration. |
| `vendor/wrpc-sw/lib/task-diags.c` | 260-285 | Main WDIAGS publisher copies dref/dout/error, prelock error, PI output/clamp, update count, state, and `pi.trace_x`. The published state bit 1 is Main frequency lock; bit 2 is phase lock. |
| `vendor/wrpc-sw/lib/task-diags.c` | 339-411 | Helper publication brackets measurement and PI epochs independently; the source explicitly notes that the measurement seqlock does not cover all PI trace fields. |
| `vendor/wrpc-sw/dev/wdiags.c` | 1263-1344 | Main frame publication uses an even/odd WDIAGS epoch and memory barriers. This proves frame coherence, not control-iteration identity. |
| `vendor/wrpc-sw/wrc_main.c` | 391, 429, 492 | `spll-bh` is created before `diags`; `wrc_poll_all_tasks()` runs in the main loop while SPLL IRQ activity may interleave. |

## Consequences for replay

1. A Main row is publication-coherent only when the before/after WDIAGS epoch
   is equal and even, and the magic/version and required numeric fields are
   valid.
2. Main trace deduplication uses `(publication_epoch, sample_n)` per board.
   Repeated keys are retained as duplicate observations but do not increase
   the unique publication count.  A changed epoch with an unchanged sample
   counter is reported as stale/duplicate publication evidence, not as new
   control progress.
3. The trace domain is derived from the published Main state bit 1: bit 1 set
   is labelled `PHASE`, otherwise `FREQUENCY`.  `PI_X` is classified only as
   `PHASE_CONTEXT_OBSERVED` or `FREQUENCY_CONTEXT_OBSERVED`; it is not treated
   as an independent proof of the producer branch.
4. Detector rows remain a separate stream from trace rows.  A detector saying
   frequency locked does not overwrite a trace row whose published state says
   otherwise, and vice versa.
5. The arithmetic relation `freq_error == dout_dt-dref_dt` is checked, but a
   mismatch or an unprovable producer-iteration pairing is labelled
   `SOURCE_COHERENCE_LIMITED` / `PRODUCER_PAIR_UNPROVEN`.  It is not promoted to
   an arithmetic-root-cause claim from sparse observer data.
6. No phase unwrap, cycle-slip fit, or phase slope is inferred from the sparse
   modulo phase observations.  Frequency-error sign, percentiles, PI output,
   clamp, domain transitions, sample progress, and host sampling gaps are
   reported directly.

## Hardware capture contract

F4I retains one source-probe reader and the already-audited direct PHY source
(`JTAG_PROBE0`, instance 0, required mask `0xCF`).  It captures the minimal
Main trace, the separate Main detector state, Helper CORE/state, Helper
position/residual data from probes 42/43/44/49, all L2 words 52-61, direct WR
core/generation/reset evidence, and Master background WR samples.  Optional PI
metadata is read once at entry and is explicitly marked as not belonging to
the same control iteration.

The capture continues through frequency-domain re-entry; a return to the
frequency domain is a research observation, not a stop condition.  It stops
only for identity/source/reader conflicts, invalid transport/data for the
specified health window, PHY regression, reset/generation change, or a WR
terminal condition.  The formal capture target is 120 seconds with a 130
second hard deadline.  It cannot establish Step5 PASS.

## Required evidence before any control change

The replay must have at least 20 unique Main publications over at least 30 s
and at least three valid 10 s background windows.  A diagnostic classification
is valid only if Helper/WR/PHY evidence and Main publication evidence are
fresh and structurally consistent.  Otherwise the result is `INCONCLUSIVE` or
`SOURCE_COHERENCE_LIMITED`, and the next action is a passive producer snapshot
request—not a PI/threshold/timeout change.
