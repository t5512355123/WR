# EXP-S6-SLAVE-RX-WORD-ALIGN-FRESH-ACQUISITION-V3-20260921

## Purpose

Run the final corrected-observer repeat for the Step6A Slave RX startup
boundary.  The only question is whether a freshly programmed Slave obtains
stable Arria-10 RX word alignment while the already-running Master transmits.
This experiment does not evaluate S_LOCK, PTP servo behavior, Global Time
validity, or the Step6B scheduled trigger.

## Fixed hardware contract

```text
SOURCE_IMAGE       = ec1f25e8
SLAVE_SOF_SHA256   = 7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e
MASTER_PROGRAM     = NO
SLAVE_PROGRAM      = YES, exact SOF only
FULL_COMPILE       = NO
FIRMWARE_BUILD     = NO
POWER_CYCLE        = NO
PHY_RESET          = NO
PTP_RESTART        = NO
MODE_COMMAND       = NO
FIBER/QSFP_CHANGE  = NO
POLARITY/BITSLIP   = NO
AUTONEG/SI5340     = NO
MDIO_WRITE         = NO
```

## Sequence

1. Read five Master TX-side precondition samples.  Require local ready,
   `PTP_STATE=6`, stable reset/configuration counters, and valid transport.
2. If and only if Phase A passes, program the exact Slave SOF once.
3. Launch the read-only observer immediately from the same host process.
4. Require three consecutive Slave local-ready samples and establish fresh
   sticky-counter baselines at that boundary.
5. Observe the word-align window for 10,000 ms from the local-ready window
   start.  Use `GAP_MS=100` and `SAMPLE_LIMIT=200`; the sample cap is only a
   safety cap and is not a formal failure gate.

## Formal gates and stop conditions

PASS requires five consecutive valid samples with:

```text
RX_LOCKED_TO_DATA = 1
RX clock activity changing
RX_SYNCSTATUS = 1
RX_PATTERN_READY = 1
RX_ENC_ERR = RX_DISPERR = RX_ERRDETECT = 0
ENC_ERR/ DISPERR/ ERRDETECT deltas = 0
```

After a complete 10-second window with no stable five-sample PASS:

- classify transient acquisition followed by loss as
  `FAIL_RX_WORD_ALIGNMENT_EARLY_LOSS_WITH_8B10B_ERRORS` when the saved
  first-sync-loss history or live evidence supports it;
- classify never-acquired alignment only when sync/pattern were never seen,
  first and final sync-loss history are zero, and 8b/10b errors increased;
- classify five consecutive RX lock/activity losses as
  `FAIL_RX_CDR_OR_RECOVERED_CLOCK_REGRESSION`.

Any transport error, reset/generation change, configuration drop, SOF hash
mismatch, late first valid sample (>5 s after programming), invalid/decreased
counter delta, sample cap, or safety deadline before a formal result is
`INCONCLUSIVE`.  Do not retry in the same session.

## Offline observer correction

V2 exposed a numeric Tcl conversion bug in `wa_delta32`: already-decoded
decimal counter values were sent through a helper that interprets transport
strings as hexadecimal.  V3 uses the corrected helper.  The analyzer also
gives `INCONCLUSIVE_COUNTER_BASELINE` precedence over the secondary
short-window label.

## Outputs

Save the exact program metadata, SOF hash, sequence timing, raw observer log,
analysis JSON, checksum manifest, and a final `REPORT.md` under this
experiment directory.  Push the report and raw evidence after observation.
