# EXP-S6-SERVO-INTERLEAVED-CKO-DMS-20260930

## Objective

Capture the Slave WR phase offset (`CKO`) with corrected-delay (`DMS`) reads
immediately before and after it, framed by `UCNT` and `SSTAT`. Sample the
already-published Global-Time validity and the five Step 5 lock indicators in
the same bounded host-time row. Determine whether the current frozen image can
hold valid Global Time, all required Step 5 locks, and `abs(CKO) < 60 ps` over
the 300-second observation window.

## Frozen scope

- Branch: `feat/file_cleanup`.
- No production C, RTL, PI/gain, threshold, timeout, SDC/QSF, clock, PPS, or
  controller changes.
- No compilation, programming, reset, or power cycle; use the current images.
- One Quartus/JTAG process at a time. No simultaneous dashboard or observer.
- Read-only source-probe reads only; no Wishbone target/ARM writes, snapshot
  requests, or servo commands.
- The archive directory `/home/b10504072/04_WR_archive_step6_pass/` is not to be
  opened, read, listed, hashed, or modified.

## Source-backed read order

The critical sequence is:

```text
UCNT before → SSTAT before → DMS high/low/high → CKO
            → DMS high/low/high → SETP → SSTAT after → UCNT after
```

The repeated high word rejects a torn 64-bit `DMS` value across a high-word
rollover. Host microsecond timestamps report both DMS windows and the CKO read
point. Stable `UCNT` and `SSTAT` are required for a coherent critical group.
Global-Time sequence/status and lock-register reads are separately timestamped;
they are not claimed to be same-cycle with the critical servo fields.

## Procedure and stop rules

1. Confirm clean source revision, expected Master/Slave JTAG cables, and no
   competing Quartus/JTAG process. Run one dashboard and save its output.
2. Run a 15-second Slave smoke at a 500 ms requested interval. Continue only
   with at least 20 rows, all critical groups trusted, zero transport errors,
   and median row duration below 250 ms. The offset need not already pass for
   this reader smoke.
3. Run one 300-second Slave capture, requested interval 500 ms, hard deadline
   900 seconds. Stop on a changed reset signature, five consecutive untrusted
   rows, transport failure, or deadline; preserve partial data as inconclusive.
4. Run a one-shot dashboard afterward. A Step 6 candidate requires both
   dashboards to show Master and Slave Global Time valid/stable, plus every
   accepted Slave sample in the complete 300-second capture to have all five
   Step 5 locks and `abs(CKO) < 60 ps`. This is sampled acceptance, not a claim
   about unobserved instants between reads or physical SMA edge skew.
5. Analyze raw data, write the report, checksum all evidence, then push.

## Interpretation limits

Even with tightly interleaved reads, Wishbone transactions are sequential.
The timestamped CKO point lies between the pre/post DMS windows, and status,
Global Time, and locks are read in separate groups. Co-occurrence supports
correlation only; it does not prove same-cycle causality. The strict offset
gate is `abs(CKO) < 60 ps` (not `<= 60`). Timing closure is not a functional
Step 6 gate. A failed capture does not authorize parameter tuning by itself.
