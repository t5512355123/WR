# EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930 — Report

## Current verdict

```text
15S_PAIRED_FRAME_SMOKE = PASS
300S_CAPTURE           = PENDING
STEP6                  = NOT ESTABLISHED
```

The short Slave-only read-only smoke passed the gates in this experiment's
plan. The 300-second diagnostic capture is authorized by that gate but has not
yet been run.

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

## Next action

After this report, analyzer fix, and smoke raw log are pushed and Pain is
fast-forwarded to the exact commit, run one 300,000 ms Slave-only capture with
`phase_context=2`, under an external 900-second hard timeout. Preserve the
reader's existing reset and five-consecutive-untrusted-row stop rules. Copy
the raw log back, verify SHA-256, analyze it, append final results here, push
the report and raw evidence, and stop. Do not interpret this diagnostic as
physical SMA edge alignment or Step 6 PASS.
