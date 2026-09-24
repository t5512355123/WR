# EXP-WRPC-STEP5-HPLL-6208-64-HELPER-PI-STATE-RAIL-AUDIT

## Verdict

```text
STEP4B_COMPLETE = YES
STEP4B_RESULT = PASS
PI_STATE_ACCOUNTING = PASS on accepted coherent snapshots
PI_OUTPUT_ACCOUNTING = PASS on accepted coherent snapshots
ANTI_WINDUP_VIOLATIONS = 0 on accepted coherent snapshots
RAIL_TRANSITION_COVERAGE = INCOMPLETE in the checked runs
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This experiment confirms the actual Helper PI state equations and the
observed lower-rail anti-windup behavior. It does not demonstrate Helper lock,
so Step5 is not complete and this branch is not approved for merge.

## Source, image, and fixed configuration

```text
Branch = exp/step5-softpll-lock
Hardware firmware commit = 1f6d732a979ce8cb7c91e1030eb651162fa1edb5
Observer script commit = 2c3ed63
Evidence commit = 1e543ae
Latest settled-dashboard evidence commit = c2370c9
Stationarity image commit = 98d9c31
Stationarity observer fix commit = 377b1aa
Stationarity evidence commit = 0b8d2ab
Board under audit = DE5 [1-11.2]

Bootstrap physical steps = 6208
Normal tracker code per physical step = 64
Polarity = A
kp = -150
ki = -2
shift = 12
bias = 5
helper threshold = 200
helper lock samples = 10000
y_min = 5
y_max = 65531
```

The added fields are read-only observability. The PI update, tracker,
SoftPLL, DMTD, PHY/PTP, reset, and lock-control behavior was not changed.

The complete firmware-to-image builds were successful:

```text
Slave MIF SHA256 = fe2ba3f57640ac79d117e2e85535eca2906e88e0254d939ff07c6169d4df52860
Master MIF SHA256 = 3ee8c03700b3cca01ad2596a47896c37cc4559670b5219027d3fcfc9b6572f860
Slave SOF SHA256 = e6645bef1e935f404650624de1fc12f1cfbe447f51893f8521e5d9bf6c0c5672b
Master SOF SHA256 = 0b75101566ea16c25a30d39643b94577fd64489b90a47aa03a5879d5b277ed69a
Slave FITTER = Successful
Master FITTER = Successful
TIMING_CLOSED = NO
```

Both devices were programmed successfully after the full firmware and
Quartus rebuild:

```text
Slave programmer checksum = 0x30B42C35, errors=0, warnings=0
Master programmer checksum = 0x30B897E6, errors=0, warnings=0
```

## Settled Step gate

The settled paired dashboard, after allowing the boards to run, reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4 Step4B Slave SoftPLL Startup pass
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

After the later fresh reprogram and the checked observer run, a new direct
settled dashboard read reproduced the same gate:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4 Step4B Slave SoftPLL Startup pass
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

This current rerun is preserved in
`raw/raw-20260830-current-settled-dashboard.txt`.

Therefore the displayed screen showing `Step 1 error` and `Step 4 SoftPLL
Startup error` is not the settled result reproduced by the latest paired
dashboard. It is consistent with an early/transient or stale dashboard read;
the final recorded Step4B gate is PASS. The raw dashboard is preserved in
`raw/raw-20260830-pair-dashboard-final-2.txt`.

## Checked PI snapshot results

The observer reads the published epoch before and after the payload and then
applies the fixed PI equations in the observer. A sample is accepted only if
the complete snapshot is mathematically coherent. A rejected snapshot is
reported separately as `PI_SNAPSHOT_REJECTS`; it is not counted as a control
or anti-windup failure.

The first checked 60-second run reported:

```text
SAMPLES = 600
VALID_FRAMES = 600
PI_TRACE_PRESENT = 600
PI_SNAPSHOT_REJECTS = 33
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
LOW_RAIL_SAMPLES = 0
HIGH_RAIL_SAMPLES = 0
FREQ_ZERO_CROSSINGS = 162
POSITION_CONTEXT_FAILS = 0
HELPER_LOCKED_FINAL = 0
RESET deltas = 0
```

The fresh-program checked run reported:

```text
SAMPLES = 600
VALID_FRAMES = 600
PI_SNAPSHOT_REJECTS = 31
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
LOW_RAIL_SAMPLES = 54
HIGH_RAIL_SAMPLES = 0
LOW_AFTER_ZERO_SEEN = 1
RAIL_TO_RAIL_CYCLE_COMPLETE = 0
POSITION_CONTEXT_FAILS = 0
HELPER_LOCKED_FINAL = 0
RESET deltas = 0
```

The longer checked run then remained at the lower rail:

```text
SAMPLES = 1800
WINDOW_SECONDS = 179.900
PI_SNAPSHOT_REJECTS = 143
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
LOW_RAIL_SAMPLES = 1800
HIGH_RAIL_SAMPLES = 0
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
PI_CLAMP_SIDE_FINAL = -1
HELPER_LOCKED_FINAL = 0
RESET deltas = 0
```

These runs prove the following on all accepted snapshots:

```text
i_new = integrator_before + ki * error
unclamped output matches the fixed PI formula
clamped output matches the Helper output
lower-rail anti-windup does not violate the hold condition
```

The checked runs did not contain high-rail samples, so full clean high-to-low
rail coverage is not claimed here. An earlier pre-filter run did observe both
rails and `RAIL_TO_RAIL_CYCLE_COMPLETE=1`, but it also contained torn-shadow
failures (`PI_ACCOUNTING_FAILS=32`, `PI_OUTPUT_MISMATCH_FAILS=8`, and
`ANTI_WINDUP_VIOLATIONS=7`), so it is retained as trajectory context, not as
clean acceptance evidence.

## Physical-floor stationarity follow-up

Following the reviewer instruction, the Slave image was rebuilt with
`ENABLE_NORMAL_HPLL_TRACKER=0`. The 6208-step bootstrap remained enabled, so
the physical actuator was allowed to complete bootstrap and then held at that
position. The observer ran for the complete requested 18,000 samples:

```text
SAMPLES = 18000
VALID_FRAMES = 17992
INVALID_FRAMES = 8
WINDOW_SECONDS = 2829.726
BOOTSTRAP_COMPLETED_FINAL = 6208
BOOTSTRAP_DONE_SAMPLE = 1
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
FORCED_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
ACTUATOR_HOLD = PASS
RESET deltas = 0
```

Using the first 300 valid post-bootstrap frequency samples as the baseline and
the configured 300-sample rolling window:

```text
FREQ_BASELINE_MEAN = 65108.5466667
FREQ_BASELINE_SIGMA = 677355.933959
FREQ_MEAN = -99733.957759
FREQ_RMS = 320629.199194
FREQ_MIN = -10927548
FREQ_MAX = 300000
ROLLING_MEAN_VIOLATIONS = 0
SUSTAINED_VIOLATION_SAMPLES = 0
PHYSICAL_FLOOR_STATIONARITY = PASS
```

The run did observe both output rails while the physical position was held:

```text
LOW_RAIL_SAMPLES = 11936
HIGH_RAIL_SAMPLES = 6033
HELPER_LOCK_COUNT_MAX = 17
HELPER_LOCKED_FINAL = 0
```

The stationarity PASS is specifically the configured rolling-envelope result;
the large baseline sigma and frequency excursions remain important evidence
that the floor behavior is not a tight frequency lock. The run therefore
does not imply Step5 success. Its settled dashboard still reported Step1/2/3
pass, `STEP4B_RESULT=PASS`, `STEP5_RESULT=NEVER_LOCKED`, and the first inactive
boundary `HELPER_LOCK`.

## Step5 conclusion

The Helper PI state is now observable and internally consistent when a
snapshot is accepted. The system nevertheless remains at the Helper-lock
boundary:

```text
HELPER_LOCKED_FINAL = 0
HELPER_LOCK_COUNT_FINAL = 0
MAIN_ENABLED = 0
PSTAT_locked = 0
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The next decision required from the experiment reviewer is whether the
partial clean rail coverage is sufficient to proceed to PI retuning, or
whether another controlled run must first force or capture a clean high-rail
to-low-rail trajectory. No merge to `main` is authorized by this report.

## Raw evidence

```text
raw/raw-20260830-checked-observer-final.txt
raw/raw-20260830-checked-observer-fresh.txt
raw/raw-20260830-checked-observer-180s.txt
raw/raw-20260830-fenced-final.txt
raw/raw-20260830-pair-dashboard-final-2.txt
raw/raw-20260830-current-settled-dashboard.txt
raw/raw-20260830-physical-floor-stationarity-1800s.txt
raw/raw-20260830-floor-settled-dashboard.txt
```
