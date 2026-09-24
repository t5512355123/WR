# EXP-S5-MAIN-FREQ-THRESH20-F4L-HELPER-CORRELATION-20260920

## Verdict

```text
THRESH20_CONTROL_PRESERVATION = PASS
F4L_DIAGNOSTIC_OWNER           = PASS
HELPER_ACQUISITION             = PASS
HELPER_LOCK_ACQUIRED_AND_HELD  = YES
MAIN_SEQUENCE_REACHED           = SEQ_WAIT_MAIN
F4L_THRESH20_FORMAL             = STILL_NOT_RUN
STEP5                           = NO
STOP_REASON                     = SAMPLE_20_COMPLETE
```

This was a bounded, read-only continuation on the same freshly programmed
threshold20 + F4L live session. No reprogramming, control-parameter change,
formal F4L capture, or second runtime gate was performed.

## Provenance

```text
FPGA/source commit             = 00d7572fa4943dbba1e28b2245f884fc04386a94
experiment-plan commit         = 929b964f
previous direct-gate report    = 7b9faa8e
observer command               = read_hpll_helper_correlation.tcl 20 500
quartus_exit                   = 0
raw SHA256                     = 4bc43cc4e367e9881fba872d315f2c5ae7dc9627d4752518d6eb895f23719973
Slave samples                  = 20
```

The prior direct gate established the preserved implementation and healthy
infrastructure for this same programmed session:

```text
Slave spll_main_limits         = 00320014
Master spll_main_limits        = 00320032
DE5A_F4L_MAIN_PHASE_DIAG       = 1 on both identities
PHY/link                       = PASS
WR handshake                   = PASS
PSTAT link                     = 1
RXERR delta                    = 0
BOOT/CPU/WR reset/SI drops     = stable
JTAG/WB transport              = TRUSTED
```

## Slave Helper correlation

All 20 Slave samples reached and held the post-acquisition sequence:

```text
SPLL_STATE                     = 00030006 (SEQ_WAIT_MAIN), 20/20
HELPER_STATE                   = 03E80001, 20/20
HELPER_LOCKED                  = 1, 20/20
HELPER_LOCK_COUNT              = 1000, 20/20
LOCK_ENABLE                    = 4, 20/20
```

The Helper control path remained active throughout the window:

```text
HELPER_ERROR_SIGNED range      = -139 .. +194
max abs helper error           = 194 (< 2000 lock band)
STEP_DELTA                     = 0 on baseline sample; nonzero on 19/19 later samples
STEP_EVENT                     = 0 on baseline; 1 on 19/19 later samples
DCO ERROR                      = 0, 20/20
HELPER_UPDATE_COUNT            = 0x003C488A -> 0x003D162A
```

The small signed error range and continuing step/update activity show that the
Helper did not merely report a stale locked shadow. `SPLL_STATE=6` also shows
that the sequence advanced from `SEQ_WAIT_HELPER` to the Main-start boundary.

## Interpretation

The previous direct snapshot stopped at `SEQ_WAIT_HELPER` because the fresh
image was still acquiring Helper lock. This bounded correlation demonstrates
that the acquisition completed on the same live session without a reprogram:

```text
SEQ_WAIT_HELPER
    -> Helper locked and held
    -> SEQ_WAIT_MAIN
```

This closes the Helper-acquisition boundary, but it does not measure Main phase
drift or prove closed-loop phase lock. Therefore it is not a Step5 pass and it
does not authorize a formal F4L capture in this same round.

## Stop and next gate

The mandated sample-20 stop condition was reached. Formal F4L remains deferred.
The next permitted diagnostic is a single direct Main runtime gate on the same
healthy session; only if Main is enabled and the runtime infrastructure remains
clean may a later round run the 120-second threshold20 F4L formal comparison.

```text
F4L_THRESH20_FORMAL = NOT_RUN
STEP5               = NO
```

## Evidence

- `PLAN.md`
- `raw/observe/helper_correlation.log`
- `raw/observe/helper_correlation.log.sha256`
