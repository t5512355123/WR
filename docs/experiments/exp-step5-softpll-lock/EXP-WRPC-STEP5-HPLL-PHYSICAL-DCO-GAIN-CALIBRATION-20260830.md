# EXP-WRPC-STEP5-HPLL-PHYSICAL-DCO-GAIN-CALIBRATION-20260830

## Verdict

```text
STEP4B = PASS
PHYSICAL_DCO_GAIN_CALIBRATION = PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The calibration acceptance criteria passed: two fresh-program repeats of
bounded 32/64/128 physical HPLL-step stimuli produced exact transaction
counts, consistent A-polarity response, and an approximately repeatable
empirical response-per-physical-step.  This is not yet a Step5 closed-loop
lock result; no normal tracker was enabled in the calibration image.

## Provenance

```text
branch = exp/step5-softpll-lock
calibration image source commit = 0ab4f50
reader commit = f2c2b8d
raw evidence commit = b1c62c7
experiment = EXP-WRPC-STEP5-HPLL-PHYSICAL-DCO-GAIN-CALIBRATION
date = 2026-08-30 (Asia/Taipei)
```

The calibration image made only the experiment controls necessary to isolate
physical response:

- normal absolute-target chasing disabled by parameter in both images;
- the previously validated A polarity retained for forced HPLL bursts;
- runtime-selected burst sizes through Slave source instance 40;
- the existing trigger and diagnostic probe indices 36–39 preserved;
- forced HPLL transaction serialization unchanged.

The burst-size control was widened to support 128 requests.  The normal
closed-loop tracker, PI gains, thresholds, DMTD, PTP/PHY, Main PLL, and reset
logic were not changed for this calibration image.

## Build and programming

The final calibration-image builds completed successfully with Quartus Prime
17.0 Build 595:

```text
Master FITTER = Successful
Slave  FITTER = Successful
Master worst setup slack = -0.191 ns
Slave  worst setup slack = -0.158 ns
TIMING_CLOSED = NO
```

Each final measurement used a fresh-programmed pair:

```text
Master cable = DE5 [1-11.1], checksum = 0x30B2299A
Slave  cable = DE5 [1-11.2], checksum = 0x30BB4C86
programmer result = 0 errors, 0 warnings
```

## Step4B regression

The final stable dashboard after calibration reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED               = YES
STEP4B_RESULT                = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

The calibration image intentionally disables normal tracking, so the same
dashboard reports no Helper/Main lock.  That is expected for this isolated
physical-stimulus experiment and is not used as a Step5 lock result.

## Transaction acceptance

For every final fresh-program repeat and every requested burst size:

```text
                                      repeat 1       repeat 2
32 physical steps: DELTA_STEP          32              32
32 physical steps: FORCED_COMPLETED    32              32
64 physical steps: DELTA_STEP          64              64
64 physical steps: FORCED_COMPLETED    64              64
128 physical steps: DELTA_STEP        128             128
128 physical steps: FORCED_COMPLETED  128             128
```

All six windows had:

```text
DELTA_BURST_TRIGGER_COUNT = 1
DELTA_FORCED_HPLL_PENDING_COUNT = requested_steps
DELTA_FORCED_HPLL_COMPLETED_COUNT = requested_steps
DELTA_STEP = requested_steps
normal tracker transactions = 0
```

Thus the physical stimulus and accounting are independently controlled; the
64-code virtual tracker mapping is not involved in these measurements.

## Drift-corrected physical response

The no-force local baseline uses the stable A01→A05 window.  After burst
completion, the first helper-update window B001→H001 is used for response
measurement.  For each window:

```text
baseline_slope = ΔPRECLAMP_ERROR / ΔHELPER_UPDATE_COUNT
corrected_response = post_burst_ΔPRECLAMP_ERROR
                    - baseline_slope * post_burst_ΔHELPER_UPDATE_COUNT
DCO_GAIN = corrected_response / physical_steps
```

```text
repeat  steps  baseline slope  corrected response  DCO_GAIN
1       32       -1119.536             +29,568       +924
1       64       -1133.495             +62,488       +976
1       128      -1133.770            +129,449      +1011
2       32       -1135.276             +30,883       +965
2       64       -1145.042             +58,712       +917
2       128      -1155.815             +91,315       +713
```

Within each fresh-program repeat, corrected response is positive and
monotonically larger for 32→64→128 physical steps.  The two repeats have the
same direction and the same order of magnitude; the six-point gain range is
approximately `713..1011`, with an overall mean of approximately `917`
corrected PRECLAMP units per physical step.

The raw TAG_DELTA samples remain noisy at this observation granularity and do
not provide a monotonic secondary gain estimate.  The repeatable
drift-corrected PRECLAMP response is therefore the accepted calibration
measurement; it must not be confused with a proof of closed-loop lock.

## Step5 lock result

This experiment deliberately paused normal target chasing and applied only
bounded physical bursts.  The final dashboard consequently remained:

```text
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
HELPER locked = 0
MAIN enabled = 0
MAIN locked = 0
PSTAT_locked = 0
```

Therefore:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The empirical gain is now available for selecting the next normal-tracker
mapping, but no mapping was guessed or merged in this experiment.

## Raw evidence

All raw evidence is committed under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-PHYSICAL-DCO-GAIN-CALIBRATION-20260830/
```

Key files:

- `calibration-repeat1-32.log`
- `calibration-repeat1-64.log`
- `calibration-repeat1-128.log`
- `calibration-repeat2-32.log`
- `calibration-repeat2-64.log`
- `calibration-repeat2-128.log`
- `dashboard-after-calibration.log`
- `build-info-master-r2.txt`
- `build-info-slave-r2.txt`
- `program-master-repeat*.log`
- `program-slave-repeat*.log`
