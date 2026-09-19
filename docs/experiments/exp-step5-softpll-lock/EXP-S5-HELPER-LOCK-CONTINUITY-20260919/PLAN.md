# EXP-S5-HELPER-LOCK-CONTINUITY-20260919

## Purpose

Follow-up to the fresh-program F4L schema smoke.  The only question was whether
the Helper error enters the ±2000 lock band and whether the lock counter leaves
its unlocked floor, while the existing DCO service continues to complete.

## Frozen boundary

- QSFP-A lane0, same freshly programmed session as the preceding F4L smoke.
- No reprogram, compile, firmware, RTL, SDB, PI, gain, threshold, timeout,
  bootstrap, arbiter, mailbox, PHY, or reset change.
- One read-only JTAG reader only.

## Command

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
```

The run was fixed at 20 samples with a 500 ms gap and was not repeated.

## Stop rule

Stop after the 20th sample.  Do not start F4L from this command.  Only a later
direct runtime confirmation may authorize another F4L smoke.
