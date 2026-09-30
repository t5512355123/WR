# EXP-S6-WR-LOCK-SUCCESS-CONTINUITY-TRACE-20261001

## Verdict

~~~text
VERDICT = INCONCLUSIVE_OBSERVER_SUCCESS_METRIC_READ_SKEW
EXACT_IMAGE_PREFLIGHT = PASS
FRESH_PROGRAM_SLAVE_MASTER = PASS
OBSERVER_CLOCK_COMPATIBILITY = PASS
CAPTURE_ROWS = 89
TRUSTED_ROWS = 89 / 89
WR_STATE_COUNTS = WRS_IDLE: 77, WRS_S_LOCK: 12
SUCCESS_CANDIDATE = NONE
SUCCESS_CONFIRMED = NONE
POSTHOC_POSITIVE_COUNTER_INTERVALS = 2 (UNCONFIRMED)
STEP5_PASS = NOT_EVALUATED
STEP6_STABLE_OFFSET = NOT_ESTABLISHED
~~~

The capture stopped after 36.157 s at the observer's configured
`FIVE_CONSECUTIVE_INVALID_SUCCESS_METRICS` guard. This is an observer/metric
inconclusive result, not a hardware failure verdict and not a Step 5/6 pass.
No follow-on hardware read or reprogramming was performed.

## Baseline and programming

- Repository: `https://github.com/t5512355123/WR`
- Branch: `feat/file_cleanup`
- Pain source commit: `906cecc8c2c2979f677c42186c1a8db7595bc9d3`
- Fixed-SETP candidate source: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- No compile and no production/control changes.
- Exact pinned SOFs were verified and programmed Slave then Master:

| Board | SHA-256 | Quartus checksum | Result |
|---|---|---:|---|
| Slave `DE5 [1-11.2]` | `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19` | `0x30B1E229` | PASS |
| Master `DE5 [1-11.1]` | `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a` | `0x30B18F28` | PASS |

The clock compatibility fix worked: Pain's Quartus Tcl reported
`S6W_CLOCK source=clock_clicks_ms`; the observer reached the board and emitted
samples. Only one read-only Slave observer was used. Wishbone timeout/invalid
counters stayed at zero and the boot/reset signature remained unchanged.
Step 1 became established early and remained established for the capture.

## Hardware observations

- 89/89 Tcl rows had `row_valid=1`; there were no invalid critical rows.
- State counts were 77 rows in `WRS_IDLE` and 12 in `WRS_S_LOCK`; no
  `WRS_LOCKED`, TX `LOCKED` (`0x1002`), or RX `CALIBRATE` (`0x1003`) row was
  captured.
- No successful-poll candidate or confirmation was established.
- The S_LOCK tail's sequence changed during its read group, so its tail fields
  are retained as context only and are not treated as coherent with the other
  groups.

The success metric was not trustworthy at the sampling cadence. For example,
sample 83 read `POLL=0x8CEC` and `UNLOCKED=0x8CEC`; sample 84 read
`POLL=0xA304`, `UNLOCKED=0xA87F`, `CALIB_FAIL=0`, producing a same-row
`LOCK_SUCCESS_TOTAL=-1403`. The sample-84 counter group spanned 114 ms, while
the three Wishbone counter reads were sequential rather than atomic. Read
skew is a plausible explanation for the negative arithmetic, but the capture
does not contain per-register timestamps and therefore does not prove that
explanation or establish firmware poll semantics from this row.

The observer currently requires the same-row derived total to be nonnegative
before it will compute the next-row counter deltas. Consequently, negative
same-row totals caused the invalid-metric streak and stopped the run. Offline
recalculation found 85/88 computable adjacent-row intervals: 83 yielded zero,
two yielded positive residuals (`+18` for samples 85→86 and `+16` for samples
87→88), and three were negative/invalid. These two post-hoc positives were
not emitted as live candidates or confirmed by the observer. Because the
counters are sequential reads and their per-register observation times were
not recorded, neither positive interval is proof of a successful poll; they
remain unconfirmed diagnostic leads.

## Offline analyzer correction

The first analyzer run reported zero valid rows because it expected uppercase
`ROW_VALID`, while the actual Tcl log emits lowercase `row_valid`. The parser
now normalizes field names before analysis; stop-reason lookup was normalized
accordingly. The corrected analysis reports 89 valid rows, 0 invalid rows,
85/88 computable adjacent counter intervals (83 zero, 2 positive, 3
invalid), and no live success candidates or confirmed rows. Ten offline tests
pass, including regressions for the actual lowercase Tcl field and separate
reporting of post-hoc positive intervals versus live confirmation.

## Raw evidence

All Pain `raw/preflight`, `raw/program`, and `raw/observe` artifacts were
copied to this experiment directory. The second-attempt observer log is:

~~~text
raw/observe/20260930T185351Z-wr-lock-success-continuity.log
SHA-256: 27ebef00fd137656742d680ff2bd66b41c48ea4b78dedb3d789c10e8abff538c
~~~

The local SHA-256 matches the Pain checksum sidecar. The earlier
clock-initialization attempt is preserved separately and had zero samples.

## Interpretation and next-step gate

This capture confirms that the repaired timer and JTAG observer can collect
valid rows through the transition from idle to `WRS_S_LOCK`. It does not
establish whether a successful `locking_poll()` occurred or what happens
after one. The current evidence points to an observer metric/read-coherence
problem that must be resolved before another hardware capture. Await the
advisor's updated recommendation; do not reprogram, rerun the observer, or
change production controls before that decision.
