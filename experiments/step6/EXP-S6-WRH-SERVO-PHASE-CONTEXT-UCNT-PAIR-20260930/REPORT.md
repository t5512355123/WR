# EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930 — Report

## Current verdict

```text
15S_PAIRED_FRAME_SMOKE = PASS
300S_CAPTURE           = COMPLETE_DIAGNOSTIC
STEP6                  = NOT ESTABLISHED
```

The Slave-only read-only smoke passed this experiment's plan gates, followed
by one 300-second capture. The capture completed without transport errors,
resets, or early-stop conditions. This diagnostic is not a Step 6 acceptance
test.

## Provenance and safety

- Branch: `feat/file_cleanup`.
- Reader source used on Pain: `d28841b4`.
- Board: Slave `DE5 [1-11.2]`; one read-only JTAG session.
- Arguments: `15000 1 1-11.2 2` (duration ms, requested inter-sample sleep ms,
  board filter, separate guarded context frame joined by UCNT).
- No firmware/RTL, PI/gain, threshold, timeout, PPS, FPGA image, reset, or
  power-cycle changes. No build or FPGA programming.
- Pain archive `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- Raw log: [`smoke_ucnt_pair_20260929T193817Z.log`](raw/observe/smoke_ucnt_pair_20260929T193817Z.log)
  - SHA-256: `52fb59a79256d78a8717612b26ebfdadb54c9c707648ac0c609983e87c44b089`
- 300-second raw log: [`capture_ucnt_pair_20260929T194612Z.log`](raw/observe/capture_ucnt_pair_20260929T194612Z.log)
  - SHA-256: `d46f2b74e8b698c5a61aa9751931e32bba914374b7999f6b59d970bdb26f69b5`

## Smoke observations

- Quartus/Tcl completed successfully; process exit `0`.
- Requested duration 15,000 ms; observed duration 15,261 ms; 49 sample rows.
- Individual reads valid: 49/49.
- Both independently guarded WDIAGS frames valid: 49/49 each.
- Same published UCNT on the two frames: 46/49 rows (93.9%), above the 75%
  minimum. Three rows are excluded from joined servo/context correlation.
- Global Time and all five Step 5 lock fields valid: 49/49 rows.
- Median row duration: 297.063 ms, below the 450 ms limit.
- Timeout, invalid-read, reset-stop, and early-stop counts: all zero.
- Joined-row servo state: `WAIT_OFFSET_STABLE` 40 rows and `SYNC_PHASE` 6
  rows. Strict `abs(CKO_PS) < 60` with live gates: 0 rows. This remains
  diagnostic evidence only; it does not establish Step 6.

## Analyzer correction discovered during smoke review

The first local analyzer verdict was `SMOKE_FAIL`, although the recorded data
met the written plan: its implementation incorrectly required every row to be
a trusted paired-context row (the plan requires at least 75%) and used a
250 ms median limit (the plan specifies 450 ms). The analyzer and regression
tests were corrected to evaluate the plan literally: paired-context floor is
75%, live gates are checked on every sample row independently of context-join
success, and median row duration must be below 450 ms. The original raw log was
not modified or recaptured. The corrected analyzer reports `SMOKE_PASS`.

Offline checks after this correction:

```text
phase-context analyzer tests: 7/7 PASS
interleaved-capture/Tcl-format tests: 10/10 PASS
git diff --check: PASS
```

## 300-second capture results

- Requested 300,000 ms; observed 300,273 ms; process exit `0`; 958 rows.
- Individual reads and primary WDIAGS frames valid: 958/958.
- Separate context-frame reads valid: 958/958; context frame guard valid:
  957/958.
- Same published UCNT across the two guarded frames: 855/958 rows (89.2%).
- Global Time and all five Step 5 lock fields valid: 958/958 rows.
- Median row duration: 295.6605 ms.
- Timeout, invalid-read, reset-stop, and early-stop counts: all zero.
- Among the 855 trusted paired rows, servo states were `WAIT_OFFSET_STABLE`
  765, `SYNC_PHASE` 86, and `TRACK_PHASE` 4.
- Strict `abs(CKO_PS) < 60` with live gates occurred in 4/855 trusted rows;
  all four were `TRACK_PHASE` with `CKO_PS=27`. The rest of the capture did
  not maintain that strict offset condition.
- Among 284 adjacent one-step UCNT pairs, CKO changed in 282, DMS in 284,
  SETP in 27, and servo state in 55. Repeated-update pairs: 568; skipped-update
  pairs: 2. These are update-ID correlations, not proof of actuator causality.

## Conclusion and stop status

The separate-frame/UCNT join produced a high fraction of trustworthy context
rows while preserving valid frame guards. Global Time and the five lock flags
were continuously reported valid in this single-board diagnostic. However,
the servo was predominantly in `WAIT_OFFSET_STABLE`, and the strict CKO offset
condition appeared only in four trusted rows. No controller settings or
production code were changed.

This experiment does not test a common future-time trigger on both DE5a boards,
measure external SMA edge skew, or establish Step 6 PASS. The requested capture
and reporting are complete; push this report and raw evidence to GitHub, sync
Pain to that commit, and stop without another hardware run.
