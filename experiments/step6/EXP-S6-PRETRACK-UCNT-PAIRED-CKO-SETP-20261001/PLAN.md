# EXP-S6-PRETRACK-UCNT-PAIRED-CKO-SETP-20261001

## Objective

Repeat the 30-second pre-TRACK phase diagnostic on the unchanged fixed-SETP
candidate, but use `phase_context=2`: read the CKO/SSTAT/UCNT payload, then
read a separate stable WDIAGS context frame and require an exact UCNT match.
This changes only the observer's join mode after the same-frame mode was
rejected in all five rows because the publication epoch advanced during the
critical read group.

The question is whether valid UCNT-matched CKO/DMS/SETP rows show the strict
`abs(CKO) < 60 ps` entry band while the servo is in `WAIT_OFFSET_STABLE` or
`SYNC_PHASE`. This is still diagnostic only: no TRACK entry means the
fixed-SETP latch was not exercised and no Step 6 smoke/pass is possible.

## Frozen image and session

- Pain repo: `/home/b10504072/04_WR`, branch `feat/file_cleanup`.
- Source used to build the running images: `a62c264dbbfc15b31c316188dd7f851d28ec2a6d`.
- Slave SOF SHA-256: `5af7150671dfb293acd82c68f47df9688fc1f23d40cf912ed3c6764467754018`.
- Master SOF SHA-256: `9a0f1087c0dd75330c94cd7f24780359d4c3d89dacd7c207d734e29568d721c5`.
- Preserve the currently running boards: no compile, reprogram, reset, or
  power cycle. The wrapper verifies build-info/source and both SOF hashes.

## Capture

```bash
quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl \
    30000 100 1-11.2 2
```

Run once, through
`scripts/run_pretrack_ucnt_paired_capture.sh`, with a 90-second external
watchdog. Use a single JTAG reader. The existing five-consecutive-untrusted
stop rule remains enabled; do not weaken it to increase row count.

Record read validity, diagnostic-frame validity/epoch, exact context UCNT
match, CKO, DMS, SETP, SSTAT, Step 1/Global-Time/all-five-lock gates, reset
signatures, row cadence, and observer errors. The context is in a distinct
publication read; UCNT equality is the join contract, not proof of an atomic
cross-register cycle.

## Interpretation and stop rules

If the observer produces at least 20 trusted rows with stable reset/link
health, report CKO range and strict in-band count by SSTAT; include every
out-of-band row. Do not require TRACK for this diagnostic, but do not call it a
fixed-SETP smoke. If fewer than 20 trusted rows are available, report the
specific failed validity/join gate as inconclusive.

Stop on SOF mismatch, missing expected cable, competing reader, fatal
transport/Tcl error, reset change, Step 1 loss, five consecutive untrusted
rows, or 30 seconds. Do not run a 300-second capture and do not change
production controls. Preserve/checksum the log, analyze on Laptop, push the
report, synchronize Pain, and stop before another hardware action.
