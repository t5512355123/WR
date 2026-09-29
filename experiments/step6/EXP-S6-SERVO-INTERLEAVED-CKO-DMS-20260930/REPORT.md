# EXP-S6-SERVO-INTERLEAVED-CKO-DMS-20260930 — Report

## Verdict

```text
INTERLEAVED_READER_SMOKE                   = PASS (22/22 individually valid; 18/22 coherent)
300S_CAPTURE                               = PASS (300340 ms; Quartus exit 0)
INDIVIDUAL_READS_VALID                     = 434/434
GLOBAL_TIME_VALID                          = 434/434
ALL_FIVE_STEP5_LOCK_BITS_HIGH              = 434/434
UCNT_SSTAT_COHERENT_ROWS                   = 382/434 (88.0%)
RESET_CHANGED / TIMEOUT / INVALID_COUNT     = 0 / 0 / 0
SAMPLED_ABS_CKO_LT_60_PS                   = 1/434
STEP6_EXPANDED_ACCEPTANCE                  = NOT_ESTABLISHED
```

The observer and dashboard both ran successfully, and the sampled Global-Time
validity and all five Step 5 lock bits remained high in every capture row. The
Slave phase offset did not stay within the strict `abs(CKO) < 60 ps` limit:
only one of 434 rows qualified, so this does **not** pass the expanded Step 6
gate or establish a Step 6 milestone.

## Provenance and scope

- Branch: `feat/file_cleanup`.
- Pain, Laptop, and GitHub source revision at capture: `08ece65e1d435110030bf2c92cf68bd05e9adaca`.
- Observer: `scripts/jtag/read_step6_servo_interleaved_offset.tcl`.
- No firmware/RTL/PI/gain/threshold/timing change, compilation, programming,
  reset, or power cycle occurred. The current image was only observed.
- The archive directory `/home/b10504072/04_WR_archive_step6_pass/` was not
  opened, listed, read, hashed, or modified.
- The programmed image was not independently read back; the capture does not
  assert a live SOF hash.
- Raw evidence and analyzer outputs are under [`raw/`](raw/) and verified by
  [`raw/SHA256SUMS`](raw/SHA256SUMS).

## Preflight and smoke

The dashboard opened in read-only mode before and after the capture. At the
preflight immediately before capture, both boards showed Link and Global Time
valid. The Slave showed Helper, Main frequency, Main phase, Main lock, and
PSTAT all high; its instantaneous offset was `+2035 ps`, so Step 6 was
`NOT QUALIFIED`. The postflight again showed both boards' Global Time valid,
the five Slave lock bits high, and offset `+2329 ps` (`NOT QUALIFIED`). An
earlier dashboard in the same session briefly observed `+42 ps`; that
instantaneous value did not persist to the capture preflight.

The final 15-second smoke produced 22 rows. Every field read was valid, 18
rows had stable UCNT/SSTAT framing, median row duration was `191.626 ms`, and
there were no transport errors or reset changes. The analyzer smoke gate passed
with its documented 75% coherent-row floor. The observed offset ranged from
`+432 ps` to `+2090 ps`; no smoke row met the strict phase threshold.

## 300-second capture

The capture ran from `2026-09-29 17:15:06 UTC` to `17:20:07 UTC`
(`2026-09-30 01:15:06–01:20:07` Asia/Taipei). Quartus reported 0 errors and
0 warnings. The observer completed 300340 ms and emitted 434 rows at a median
sample spacing of `692 ms` (maximum `706 ms`); median row duration was
`191.346 ms`.

| Measure | Result |
|---|---:|
| Individually valid rows | 434/434 |
| Stable, UCNT/SSTAT-framed rows | 382/434 (88.0%) |
| Global-Time-valid rows | 434/434 |
| Rows with all five Step 5 lock bits high | 434/434 |
| Rows with `abs(CKO) < 60 ps` | 1/434 |
| Rows satisfying time + all locks + strict offset | 1/434 |
| CKO range over valid reads | −3989 to +2419 ps |
| Boot/reset signature changes | 0 |
| Reader timeout / invalid counters | 0 / 0 |

The DMS/CKO read order was materially tighter than the previous observer:
the median CKO timestamp was `11.639 ms` after the pre-DMS window ended, and
the median post-DMS window began `2 μs` after the CKO timestamp (maximum
`10 μs`). Each DMS value still consists of sequential Wishbone reads, and the
other validity/lock groups are separately sampled; this is not an atomic
same-cycle snapshot.

## Interpretation and next step

Global Time and the five Step 5 lock bits were continuously *sampled* as high
at this observer's cadence, but phase offset remained thousands of picoseconds
from the target for nearly the entire run. Only one sampled row met the full
Step 6 conjunction. Pre/post dashboards agree with the capture's failure.

This establishes the next boundary more clearly, but does not identify a root
cause: sequential co-occurrence cannot prove that DMS, UCNT, or any servo action
caused the offset movement. Do not change gains, thresholds, firmware control,
or timing constraints based on this report alone. Step 6 stays
`NOT_ESTABLISHED`; historical dual-board digital-trigger evidence is
unchanged. Physical SMA/output-edge skew remains unevaluated, and timing
closure remains outside the functional gate.

## Source audit of the WRH servo transitions

Read-only audit of `vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c` shows:

- The update copies `gs->offsetFromMaster` into `offsetMS`, separately records
  `delayMS`, then increments `gs->update_count` before the `readyForSync`, PLL
  lock, and hardware-adjust-in-progress gates. Therefore an update-counter
  increment alone is not proof that a phase adjustment completed.
- `WRH_SYNC_PHASE` converts the current offset to ticks/phase, adds the phase
  remainder to `cur_setpoint_ps`, issues `adjust_phase()`, and enters
  `WRH_WAIT_OFFSET_STABLE`.
- `WRH_WAIT_OFFSET_STABLE` enters `WRH_TRACK_PHASE` only when the absolute
  `offsetMS` is strictly below `WRH_SERVO_OFFSET_STABILITY_THRESHOLD` (60 ps).
  Otherwise it increments `missed_iters`; at 10 misses it resets that counter
  and returns to `WRH_SYNC_PHASE`.
- In `WRH_TRACK_PHASE`, `abs(offset_ps) > 2 * threshold` (strictly greater
  than 120 ps) returns to `WRH_SYNC_PHASE`. Otherwise, when tracking is
  enabled, the code adds `offset_ps / 4` to the phase setpoint and requests
  another hardware phase adjustment.
- `task-diags.c` refreshes WDIAGS on a 100 ms cadence. It clears
  `WDIAGS_CTRL.DATA_VALID` for the refresh, then writes `SSTAT`, `DMS`, `CKO`,
  `SETP`, and `UCNT`; `CKO` is the signed `offsetFromMaster` converted to ps,
  `DMS` is `delayMS`, and `UCNT` is PPSI's servo `update_count`. The mapping
  counter/inverse at WDIAGS offsets `0x134/0x138` advances once per refresh in
  the current image. Therefore these values are a periodically published
  software diagnostic cache, not a set of live atomic hardware registers.

These source thresholds are consistent with the observed state-machine
boundaries, but do not explain why CKO moves by thousands of picoseconds or
establish that DMS/update-counter changes caused it. This audit also found a
missing observation guard in the previous reader: it did not bracket the
critical group with WDIAGS frame-valid and publication-epoch checks. A
follow-on read-only experiment now adds those checks around a minimal
CKO/SSTAT/UCNT payload and is described in
[`EXP-S6-WDIAGS-FRAME-VALIDITY-20260930/PLAN.md`](../EXP-S6-WDIAGS-FRAME-VALIDITY-20260930/PLAN.md).
Only after a valid smoke should a longer capture be interpreted. No control
tuning or frozen-image change is justified yet.
