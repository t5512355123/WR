# EXP-S6A-ACTIVE-EXTENSION-LATE-GLOBAL-TIME-TAIL-20260922

## Purpose

Observe the already programmed Step6B V2 session for an additional 45 seconds
after Slave reaches the active-extension state. The only question is whether
Slave Global Time/PPS validity recovers late without any recovery write.

## Fixed contract

```text
MASTER/SLAVE COMPILE = NO
FIRMWARE BUILD       = NO
MASTER/SLAVE PROGRAM = NO
MASTER/SLAVE PTP RESTART = NO
CPU/WR/PHY RESET     = NO
POWER CYCLE          = NO
TARGET/ARM WRITE     = NO
FIBER/QSFP/AUTONEG   = NO CHANGE
SI5340/MDIO          = NO CHANGE
WINDOW               = 45000 ms
```

The observer first requires three paired current-session samples. Master must
remain link-up and time-valid; Slave must remain link-up, RX-pattern-ready,
SoftPLL sequence-ready, PSTAT/Main locked, and in `PTP_STATE=9`,
`PD_STATE=3`, `EXT_STATE=1`, `WRC_MODE=3`. Time/PPS validity is intentionally
not a Slave gate at this stage because it is the measurement target. Reset
signature must remain generation/counts equal to one.

The 45-second tail is read-only. Formal PASS requires at least five
consecutive valid Slave samples, snapshot count advancing by at least two,
three common TAI labels with equal cycles, and zero cycle delta. A complete
active-extension tail with no valid time is classified as
`FAIL_ACTIVE_EXTENSION_GLOBAL_TIME_STUCK`; terminal fallback or loss of the
SoftPLL-ready state has its own stop classification. No PTP restart is allowed
in this experiment, even if the terminal fallback appears.

Step6B trigger and physical SMA edge timing are not run or evaluated here.
