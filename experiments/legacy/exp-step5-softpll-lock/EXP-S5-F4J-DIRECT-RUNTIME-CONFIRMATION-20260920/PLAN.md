# EXP-S5-F4J-DIRECT-RUNTIME-CONFIRMATION-20260920

## Purpose

Confirm the Main operating state on the same freshly programmed F4J image/session after the Helper acquisition correlation. This is a single read-only gate confirmation. It is not the F4J producer audit.

## Fixed session and command

Keep the current F4J image and live session unchanged. Run exactly once:

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

Evaluate the Slave for link, PTP/parent calibration, Helper lock, `SPLL_SEQ_STATE=6`, Main enabled/frequency lock, reset stability, RXERR, and trusted JTAG/WB transport. `MAIN_PHASE_LOCKED=0` and `PSTAT_LOCKED=0` are expected research-state observations, not this gate's failure criteria.

## Freshness stop rule

Even if the operating-state gate passes, stop if the raw runtime still contains a sticky historical WR failure reason. The current F4J observer uses legacy terminal semantics and may misclassify that reason as a new terminal. In that case classify `F4J_OBSERVER_FRESHNESS_BLOCKER=YES`, do not run the 30-second F4J audit, and wait for an observer-only fix decision.

## Actual outcome

The Slave operating gate passed, but `LOCK_RESULT_RAW=6D6E0601` decodes to failure-reason bits `[15:9]=3`, and the diagnostic reports a historical `WRS_S_LOCK` timeout. Therefore this experiment stops at the freshness boundary. No F4J producer frames were collected.
