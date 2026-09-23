# Step6 functional milestone

## Status

```text
STEP6A_GLOBAL_TIME_VALIDITY = PASS
STEP6A_SAME_PPS_CONSISTENCY = PASS
STEP6B_DIGITAL_SCHEDULED_TRIGGER = PASS
STEP6_PHYSICAL_OUTPUT_EDGE = NOT_EVALUATED
```

Step6A requires valid, stable, advancing Global-Time/PPS snapshots on both
boards and a same-PPS comparison. Step6B requires both boards to accept the
same future `(TAI, cycles)` target, fire exactly once at that target, retain
healthy runtime state for the required post-fire samples, and show no reset
or snapshot-coherence violation.

The current implementation has met those digital functional requirements:
five shared PPS labels had an exact cycle match, and the two scheduled
triggers both recorded `(TAI=1133, cycles=62500000)` with one fire each and
three healthy paired post-fire samples. The zero-tick delta is equality at
the internal 125 MHz / 8 ns label resolution; it is not a physical output
skew measurement.

## Exact current evidence

The current Step5-plus-Step6 hardware validation is recorded in
[`EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md`](EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md).
The exact SOF/MIF files are retained on Pain under:

```text
/home/b10504072/04_WR/artifacts/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/
```

External trigger-pin/PPS edge skew remains a separate physical measurement and
must not be inferred from the internal timestamp comparison.
