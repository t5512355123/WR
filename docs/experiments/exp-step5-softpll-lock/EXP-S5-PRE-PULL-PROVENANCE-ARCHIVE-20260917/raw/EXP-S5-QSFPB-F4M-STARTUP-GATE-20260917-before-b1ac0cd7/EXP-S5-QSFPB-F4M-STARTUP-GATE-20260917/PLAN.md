# EXP-S5-QSFPB-F4M-STARTUP-GATE-20260917

## Purpose

Repeat the QSFP-B Step5 F4M startup capture after the previous fresh-firmware
run stopped before the Slave Helper/Main startup boundary.  This experiment
changes only the read-only observer scheduling:

```text
before F4L read:
  wait for existing Helper_LOCKED=1 and Main_ENABLED=1
after gate:
  run the existing 34-word F4L reader and first-loss correlation
```

The gate reads the existing WDIAGS Main-state shadow at `0x00100AC4`; it does
not write hardware or feed the value back into any control path.  Before the
gate, invalid F4L data is classified as startup waiting rather than
`DATA_UNRESOLVED`.  If the gate is not reached within 30000 ms, the observer
stops as `STARTUP_GATE_NOT_REACHED`.

## Frozen scope

- QSFP-B lane 0 diagnostic topology.
- Existing fresh firmware identity and all Step5 control parameters.
- No production C/RTL, PI/gain, threshold, timeout, bootstrap, detector,
  anti-windup, DAC, arbiter, mailbox, PHY, reset, or SDB changes.
- One read-only JTAG observer; no Helper PI snapshot and no debug-FIFO drain.

## Procedure

Laptop:

```text
push the observer change and this plan
```

Pain:

```text
pull the exact commit
rebuild the existing QSFP-B Slave/Master JTAG images
program Slave DE5 [1-11.2] first, then Master DE5 [1-11.1]
run read_probe.tcl as preflight
run the same bounded F4M observer with 60000/70000 ms duration
```

The resulting raw build, programmer, preflight, and observer files belong in
this experiment directory.  The report must distinguish:

```text
STARTUP_GATE_REACHED + valid F4L pages
STARTUP_GATE_NOT_REACHED
WR/PHY transport failure
```

No Step5 PASS is possible unless the later F4M evidence also meets the
repository's sustained Main/Helper/phase/PSTAT lock criteria.
