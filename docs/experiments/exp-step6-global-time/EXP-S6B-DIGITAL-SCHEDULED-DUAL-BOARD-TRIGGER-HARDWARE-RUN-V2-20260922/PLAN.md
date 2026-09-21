# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-HARDWARE-RUN-V2-20260922

## Purpose

Re-run the approved Step6B-1 digital scheduled dual-board trigger using the
same fitted Master and Slave SOFs. V2 changes only the Pain programmer
invocation from the failed sudo wrapper to the verified direct non-sudo
Quartus Programmer path. The scheduler, observer, fitted design, firmware,
and timing proof remain unchanged.

## Fixed artifact contract

```text
DESIGN_SOURCE_COMMIT = c24568e383be3355ac8684b7d13f293115931586
SLAVE_SOF_SHA256     = 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
MASTER_SOF_SHA256    = 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
POSTFIT_TIMING       = PASS_STEP6B_POSTFIT_TIMING_PROVEN
TARGET_CYCLES        = 62500000
COMPILE              = NO
FIRMWARE_BUILD       = NO
RTL/SDC/QSF/MIF      = NO CHANGE
```

Any provenance mismatch stops before programming with zero program count. No
new SOF may be generated.

## Direct programming contract

Use the exact existing SOFs and no wrapper or sudo:

```text
1. quartus_pgm -c "DE5 [1-11.2]" -m jtag -o "p;<exact Slave SOF>"
2. quartus_pgm -c "DE5 [1-11.1]" -m jtag -o "p;<exact Master SOF>"
```

Each command is allowed exactly once. Master is attempted only after Slave
success. Each log must identify the requested cable, show one device
configured, `Configuration succeeded`, `Successfully performed operation(s)`,
and zero errors. Any failure stops without retry, reset, or alternate method.

## Hardware and observer contract

No power cycle, CPU/WR/PHY reset, PTP restart, mode command, QSFP/fiber
change, SI5340/MDIO write, or SMA routing change is allowed. After both
programs, the observer first requalifies Step6A without writing target or ARM.
The only permitted recovery is one Slave-only `ptp stop`/`ptp start` if the
exact previously defined terminal-fallback signature appears. Otherwise an
unqualified pre-arm state stops the run.

The scheduled target is the latest common snapshot TAI plus 20 seconds and
`TARGET_CYCLES=62500000`. Target is written once per board while ARM is zero;
ARM is raised once per board. Formal PASS requires both boards to fire once at
the exact target TAI/cycles, digital delta 0 ticks/0 ns, and three additional
read-only post-fire samples. Physical SMA edge timing remains not evaluated.

