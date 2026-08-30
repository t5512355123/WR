# EXP-WRPC-STEP5-HPLL-6208-FIXED-ACTUATOR-COHERENT-DMTD-MEASUREMENT-AUDIT

## Verdict

```text
DMTD_MEASUREMENT_COHERENCE = PASS
EXTREME_CLASSIFICATION = A_CROSS_EPOCH_ARTIFACT
ACTUATOR_HOLD = PASS
RESET_STABLE = PASS
STEP4B_RESULT = PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This experiment closed the measurement-coherence question raised by the
physical-floor stationarity run. The earlier million-scale `FREQ_ERROR`
excursions were not reproduced when the values were taken from one coherent
Helper-update payload. They were therefore classified as cross-epoch shadow
artifacts. This does not demonstrate Helper lock or complete Step5.

## Scope and configuration

```text
Branch = exp/step5-softpll-lock
Hardware/source commit = cd7a67b278f4b3adb3030c5594ba04b0566662ce
Observer address-fix commit = 11a7fbf
Evidence commit = 91136b3
Board = DE5 [1-11.2]

BOOTSTRAP_STEPS = 6208
ENABLE_STEP5_BOOTSTRAP = 1
ENABLE_NORMAL_HPLL_TRACKER = 0
Polarity = A
kp = -150
ki = -2
threshold = 200
lock_samples = 10000
```

The functional configuration was unchanged. The implementation added only
read-only measurement observability: `helper_update()` captures one complete
payload in a RAM seqlock, and the periodic diagnostics task mirrors that
coherent payload into the private WDIAGS window. No PI formula, DMTD/PHY/PTP
logic, actuator admission, reset tree, or SoftPLL control decision was
changed.

The payload is:

```text
MEASUREMENT_EPOCH
TAG_DELTA_USED
EXPECTED_DELTA_USED
FREQ_ERROR_USED
PRECLAMP_ERROR
HELPER_ERROR
HELPER_OUTPUT
HELPER_UPDATE_COUNT
DMTD_REF_ACCEPT_COUNT
DMTD_FB_ACCEPT_COUNT
```

The observer brackets the complete WDIAGS payload with
`epoch_before -> payload -> epoch_after` and accepts only an unchanged even
epoch. `FREQ_ERROR_USED` is checked against
`TAG_DELTA_USED - EXPECTED_DELTA_USED` for every accepted snapshot.

## Build and programming evidence

```text
Slave MIF SHA256 = 5fde5df093c9fddbeab5e389cacf274e111afbc4afe109fa677205a79e349cd3
Slave SOF SHA256 = b6f23648932149aa9d767ee1ad2f259e6cc74285d0685625cc08d77b4400f5a9
Master SOF SHA256 = 0b75101566ea16c25a30d39643b94577fd6489b90a47aa03a5879d5b277ed69a
Slave FITTER = Successful
TIMING_CLOSED = NO
```

Both boards were programmed successfully after the Slave rebuild:

```text
Slave checksum = 0x30BF3303, errors=0, warnings=0
Master checksum = 0x30B897E6, errors=0, warnings=0
```

## Coherent measurement result

The formal observer ran for 1,800 samples. The measured elapsed time was
390.397 seconds because each sample performs a bracketed multiword JTAG
read.

```text
SAMPLES = 1800
COHERENT_MEASUREMENT_SNAPSHOTS = 1800
REJECTED_EPOCH_SNAPSHOTS = 0
MEASUREMENT_ACCOUNTING_FAILS = 0
FREQ_ERROR_MEAN = -58.535
FREQ_ERROR_RMS = 59.7828803068
FREQ_ERROR_MIN = -91
FREQ_ERROR_MAX = -23
EXTREME_THRESHOLD = 1000000
EXTREME_COHERENT_SAMPLES = 0
EXTREME_CLASSIFICATION = A_CROSS_EPOCH_ARTIFACT
DMTD_MEASUREMENT_COHERENCE = PASS
```

The fixed actuator remained stationary after bootstrap:

```text
BOOTSTRAP_COMPLETED_FINAL = 6208
BOOTSTRAP_DONE_FINAL = 1
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
FORCED_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
ACTUATOR_HOLD = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
RESET_STABLE = PASS
```

The source-backed accepted counters advanced during the run, while the
actuator transaction counters remained unchanged. The final coherent sample
was:

```text
MEASUREMENT_EPOCH = 2811146
HELPER_UPDATE_COUNT = 1405573
DMTD_REF_ACCEPT_COUNT = 140252482
DMTD_FB_ACCEPT_COUNT = 130415664
TAG_DELTA_USED = 16314
EXPECTED_DELTA_USED = 16384
FREQ_ERROR_USED = -70
```

## Settled Step gate

After the fresh paired programming and the coherent audit, the read-only
settled dashboard reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4 Step4B Slave SoftPLL Startup pass
STEP4A_RESULT = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

Therefore Step4B is confirmed PASS in the settled paired run. A screen that
shows Step1/Step4 as `error` is an early/transient or stale dashboard read;
the reproduced settled result is the one preserved in the raw dashboard
log. The real remaining functional boundary is Helper lock.

## Step5 conclusion

This experiment proves that the large stationarity-run excursions were caused
by incoherent shadow sampling across successive Helper updates. It does not
prove frequency convergence, phase convergence, `PSTAT.locked`, or long-term
closed-loop stability. The branch therefore remains unapproved:

```text
HELPER_LOCKED_FINAL = 0
PSTAT_locked = 0
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

No merge to `main` is authorized.

## Raw evidence

```text
artifacts/EXP-WRPC-STEP5-HPLL-6208-FIXED-ACTUATOR-COHERENT-DMTD-MEASUREMENT-AUDIT/
  raw-20260830-coherent-measurement-audit-180s.txt
  raw-20260830-coherent-smoke-staged.txt
  raw-20260830-settled-dashboard.txt
  raw-20260830-crosscheck-correlation.txt
```

The observer source is:

```text
scripts/jtag/read_step5_fixed_actuator_coherent_dmtd_measurement_audit.tcl
```
