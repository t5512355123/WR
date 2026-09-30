# EXP-S6-WR-LOCK-SUCCESS-CONTINUITY-TRACE-20261001

## Purpose

Determine whether the first source-backed successful Slave `locking_poll()`
after fresh programming is followed by a continuous WR admission sequence, or
whether the session stalls/loses SoftPLL lock. This is a read-only boundary
experiment; it does not test phase convergence or Step 6 offset acceptance.

## Exact baseline

- Repository: `https://github.com/t5512355123/WR`
- Branch: `feat/file_cleanup`
- Evidence baseline: `ad6998e5483a272b13253e73640e3acf8e169e98`
- Fixed-SETP candidate source: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Slave `DE5 [1-11.2]` SOF SHA-256:
  `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19`
- Master `DE5 [1-11.1]` SOF SHA-256:
  `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a`

Expected Pain image paths are the same pinned frozen milestone outputs used by
the previous experiment:

~~~text
artifacts/milestones/step6_global_time/source/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
artifacts/milestones/step6_global_time/source/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof
~~~

If either exact hash is absent or mismatched, stop before programming. Do not
compile, rebuild, substitute another image, reset, or power-cycle.

## Single permitted change

Passive JTAG observer, offline analysis/tests, wrapper, and this experiment's
records only. Production C/RTL, `wrh-servo.c`, `wrpc-spll.c`, WR state-machine
code, PI/gain, lock thresholds/samples, timeout constants, DMS/PTP and image
content remain unchanged.

The observer uses the existing read-only `read_wb_runtime.tcl` mailbox
contract and a single Slave JTAG session. It sends no shell command, performs
no Wishbone control write, requests no DATA_SNAPSHOT/Helper PI snapshot, and
does not read the previous experiment's DMTD/TAG/TRR/IRQ event chain.

## Source-mapped fields

The map was checked against the frozen source snapshot, `task-diags.c`,
`wrpc-spll.c`, `state-wr-s-lock.c`, `wdiags.c`,
`wrc_diags_regs.h`, and `docs/debug/jtag_register_map.md`.

| Group | Read-only fields |
|---|---|
| Health | Step 1 status; boot generation; CPU, WR-core and SI reset signatures |
| WR admission | WR state/next state; RX/TX message IDs and counters; failure reason/count; reject reason/count |
| locking poll | last result; poll/unlocked/calibration-fail/enable counters; source-defined success total and per-interval delta |
| S_LOCK tail | sequence-bracketed magic, stage, retry, remaining time, last published poll detail, WR state, sequence |
| Downstream | SPLL sequence; Helper lock; Main enabled/frequency/phase/Main lock; PSTAT lock; servo state; UCNT |

The source maps `WRH_SPLL_LOCKED` to return code 0. Each `locking_poll()`
increments `LOCK_POLL_COUNT` and then exactly one of `LOCK_UNLOCKED_COUNT`,
`LOCK_CALIB_FAIL_COUNT`, or neither (successful return). Therefore:

~~~text
SUCCESS_POLL_DELTA = ΔPOLL - ΔUNLOCKED - ΔCALIB_FAIL
~~~

The counters are separate Wishbone reads, not an atomic snapshot. A positive
candidate is confirmed only when a following trusted row preserves a
nondecreasing success total. Candidate and confirmation times use the
monotonic counter-group read brackets; the 5-second continuation starts at
the confirmation bracket, conservatively after the candidate event. The
S_LOCK tail's sequence is checked as its publish-last marker. Its poll-detail
fields are retained as context, not treated as atomic with the counter group.

## Capture protocol

1. Laptop runs offline tests, commits, and pushes this observer/plan.
2. Pain fast-forwards to that commit and verifies both exact SOF hashes.
3. Do not compile. Program the exact Slave image, then exact Master image,
   then immediately start this one Slave observer. No dashboard or second
   JTAG reader in between.
4. Poll continuously with no artificial post-row delay. The observer records
   monotonic row/counter/tail timing and actual row spacing.
5. Capture until a confirmed first success plus 5,000 ms, or one of the
   pretrigger/immediate stop conditions below. Pretrigger is capped at
   300,000 ms.
6. Transfer raw/checksum to Laptop, verify SHA-256, analyze, update this
   report, then push the result. Do not start another hardware experiment
   without a fresh advisor decision.

## Stop conditions

Immediately stop on:

- exact SOF hash mismatch, no/ambiguous Slave target, fatal Tcl/JTAG error;
- boot generation, CPU reset, WR-core reset, or SI-config reset signature
  changes;
- Step 1 drops after it has once been established;
- five consecutive invalid critical rows;
- five consecutive invalid success-counter metric rows.

Stop before success if three consecutive trusted rows show the previously
active WR session has left its active state and a source-valid failure reason
is present. Stop at 300,000 ms with
`NO_SUCCESSFUL_LOCK_POLL_300S` if no confirmed success occurred.

After first success is confirmed, continue for 5,000 ms and stop with
`POST_SUCCESS_WINDOW_COMPLETE`, unless an immediate stop condition occurs.
Do not stop just because locks are low, servo state is 1/3/5, Global Time is
invalid, or CKO exceeds a threshold.

## Interpretation limits

The observer reports timestamped correlation, not same-cycle causality. A
single positive counter difference is only a candidate until confirmed by a
second trusted row. The analyzer must distinguish:

- successful poll followed by WR state/signaling progression;
- success followed by `WRS_LOCKED`/TX `LOCKED` without RX `CALIBRATE` and a
  source-valid WR timeout;
- SoftPLL unlock/lock-gate loss after success without a prior WR timeout;
- no successful admission reproduced within 300 seconds.

None of these outcomes alone is a Step 5 or Step 6 pass.

## Status

~~~text
IMPLEMENTATION = OFFLINE_VALIDATED
SOURCE_MAP_AUDIT = PASS
OFFLINE_TESTS = PASS (10 tests; field-case and post-hoc interval regressions)
TCL_PARSE_AND_STUB_SMOKE = PASS (Tcl 8.6.12; simulated candidate/confirm/5-second stop)
PAIN_PULL = 906cecc8c2c2979f677c42186c1a8db7595bc9d3 (PASS)
SOF_HASH_PREFLIGHT = PASS (both pinned SHA-256 values)
FRESH_PROGRAM_SLAVE_MASTER = PASS (no compile; exact images)
CLOCK_COMPATIBILITY_FIX = PASS_ON_PAIN
HARDWARE_CAPTURE = INCONCLUSIVE_OBSERVER_SUCCESS_METRIC_READ_SKEW
CAPTURE_ROWS = 89 / 89 TRUSTED; LIVE_SUCCESS_CANDIDATE = NONE
POSTHOC_POSITIVE_COUNTER_INTERVALS = 2 (UNCONFIRMED)
STOP_REASON = FIVE_CONSECUTIVE_INVALID_SUCCESS_METRICS (36.157 s)
OFFLINE_ANALYZER_FIELD_CASE_FIX = PASS
RAW_TRANSFER_AND_CHECKSUM = PASS
NEXT_HARDWARE_ACTION = WAIT_FOR_ADVISOR
STEP6_STABLE_OFFSET = NOT ESTABLISHED
~~~
