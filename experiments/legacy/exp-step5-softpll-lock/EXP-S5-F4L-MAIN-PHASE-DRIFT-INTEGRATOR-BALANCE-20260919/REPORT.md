# EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260919

## Verdict

```text
QSFP_A_LANE0_LINK       = PASS
QSFP_A_LINK_STABILITY   = PASS (within the capture window)
F4L_SCHEMA_SMOKE        = FAIL / STOPPED
F4L_DIAGNOSTIC          = INCONCLUSIVE
STEP5                   = NOT PASS
```

This run confirms that restoring the known-good QSFP-A lane-0 source route
brings the White Rabbit upstream link back. The Step5 F4L phase/integrator
diagnostic did not produce a valid frame, so no phase or integrator conclusion
is allowed from this run.

## Purpose and fixed controls

The run followed `ai_advice/Step5/14_Astra.md` and the local `PLAN.md`.
It used the passive Main-DAC0 F4L diagnostic only. The control baseline was
kept fixed:

- Main Kp/Ki/boost: `300 / 1 / 20`;
- Slave Kp/Ki/boost: `300 / 1 / 20`;
- Helper Kp/Ki: `-2250 / -2`;
- Slave bootstrap: `3388`;
- Master bootstrap disabled; candidate `0/0`;
- timeout, thresholds, lock/delock samples, PI/anti-windup, arbiter,
  mailbox, detector, DAC behavior/order, PHY, reset, RTL and SDB unchanged.

The source head was `c4095e7535d1e179e5aef88d2c8ee61130275a88`. The QSFP-A
route restoration is from `ef3223adb0fa226f9e412e179c1d963ce11f4574`:

- both Master and Slave route WR data through `QSFPA_TX_p(0)` and
  `QSFPA_RX_p(0)`;
- inactive TX lanes 1 through 3 are held low;
- the known-good lane-0 TX first-post-tap is retained.

The observer itself remained read-only: one reader, no control write, no
Helper PI snapshot, no debug FIFO drain, no shared control-ABI extension, and
no RTL/SDB change.

## Build and programming

Both Quartus builds returned success, with the existing implementation caveat
`timing_closed=NO`:

```text
Slave SOF SHA256  17c527a68a58377ee4efab2961fe2ea6bb593d0e78b4f741d0a01af6132f5e8a
Master SOF SHA256 a5c6af94b658340bd0ebe39a8c178358ed322f468cb27331d6b23bd1c7752dba
```

Programming completed with zero errors and zero warnings:

```text
Slave  DE5 [1-11.2]  checksum 0x30B5B27A
Master DE5 [1-11.1]  checksum 0x30AFA169
```

The offline regression checks completed before build:

```text
test_step5_f4l.py: 5 tests PASS
test_step5_f4s.py: 7 tests PASS
F4L contract/static checks: PASS
git diff --check: PASS
```

The bundled Python runtime was used to execute the test functions directly;
the environment did not provide the `pytest` package.

## Link preflight and stability evidence

The post-program preflight returned valid probe values:

```text
Master probe_hex = 00109AE137BC82FF
Slave  probe_hex = 711E46C1285082EF
PREFLIGHT_LINK    = PASS
```

During the F4L capture, both endpoints repeatedly reported:

```text
CORE_TM_LINK_UP=1
CORE_LINK_OK=1
WR_RX_READY=1
WR_TX_READY=1
PHY_LINK_USABLE=1
PSTAT_LINK=1
TERMINAL=0
WR_CORE_RESET_COUNT=0
SI_CONFIG_DROP_COUNT=0
```

The Master and Slave therefore had a usable link throughout the short capture
window. This is strong code-path evidence that the earlier QSFP-A failure was
caused by the lane-2 route in the diagnostic image, not by the replaced
physical cable.

## F4L result

The observer was configured for a 10-second smoke gate, a 120-second formal
target, and a 130-second hard limit. It stopped at 11,215 ms because the
required three-page F4L schema never became readable:

```text
STEP5_F4L_DONE
  smoke_ok=0
  diag_valid=0
  diag_unique=0
  page0=0 page1=0 page2=0
  run_end_reason=STOP_F4L_SMOKE_SCHEMA_NOT_READY
  step5_complete=NO
  step5_pass=NO
```

The offline analyzer independently classified the raw capture as:

```json
{
  "classification": "FRAME_SCHEMA_INVALID",
  "frame_count": 0,
  "invalid_frame_count": 4,
  "diagnostic_pass": false,
  "step5_pass": false
}
```

All four attempted Main diagnostic reads had `MAIN_F4L_VALID=0`, an
incomplete raw frame, and no valid page/epoch/update identifiers. Therefore
there is no trustworthy phase histogram, frequency-conditioned phase data,
integrator delta, or same-generation pair from which to infer phase drift.

The accompanying Helper observations show the next boundary rather than a
link failure:

```text
HELPER_UPDATE_COUNT  increased
HELPER_BOOTSTRAP_DONE=1
HELPER_TARGET_CODE=5
HELPER_APPLIED_CODE=5
HELPER_LOCKED=0
PSTAT_LOCKED=0
```

The F4L startup gate requires `HELPER_LOCKED_AND_MAIN_ENABLED`; that gate was
not reached during this smoke window. This explains why the passive Main F4L
frame was unavailable, but it does not prove the cause of the missing Helper
lock.

## Boundary and next action

This experiment successfully repairs and validates the QSFP-A lane route, but
it does not pass Step5. The next experiment must keep lane 0 fixed and first
diagnose the Helper/Step4B startup boundary with a read-only, schema-valid
observer. It must not change PI/gain/threshold/timeout/bootstrap or declare a
phase result until `HELPER_LOCKED` and valid F4L pages are both observed.

This report deliberately stops here; no control-parameter experiment or merge
claim is made.

## Raw artifacts

- `PLAN.md`
- `APPROVAL.md`
- `manifest.txt`
- `build_slave.log`
- `build_master.log`
- `program_slave.log`
- `program_master.log`
- `preflight_link.log`
- `capture_f4l.log`
- `analysis/f4l_analysis.json`
