# EXP-WRPC-STEP5-HPLL-6208-128-FROZEN-FIT-KP-MINUS300-VS-MINUS301-MIF-ONLY-AB-600S-20260902

## Scope

Frozen-fit A/B experiment requested by the branch-5 review.  The canonical
Quartus fitted database was retained; no fitter or STA rerun was performed
between A and B.  The only functional image change was the WRPC firmware PI
proportional gain:

- A: `kp=-300`, `ki=-1`
- B: `kp=-301`, `ki=-1`

Both images use bootstrap `6208`, code-per-physical-step `128`, shift `12`,
bias `5`, output range `5..65531`, lock threshold `200`, lock samples `10000`,
and lane 2 on Slave cable `DE5 [1-11.2]`.

## Frozen-fit provenance

The canonical fitted hardware is the previously verified kp=-301 design from
source commit `d0314a2e87e5b5674bbe8ebcf7626afbb2591c0a`.  The existing Quartus
fit database and incremental database were backed up before the experiment.
For both A and B, Quartus `quartus_cdb --update_mif` followed by
`quartus_asm` completed successfully; the fitter was not rerun.

The MIF comparison was normalized for the non-functional embedded version
string.  The resulting A/B MIF difference is one firmware instruction at MIF
address `0x61F8`:

```text
kp=-301: ED300713
kp=-300: ED400713
```

| Artifact | kp=-300 (A) | kp=-301 (B) |
|---|---|---|
| Master MIF SHA-256 | `824a762d9826e875732d6ac24e5dc725b64bea07c30c7623fc3a3bd184ce3f8b` | `72d8c94e64f56e3128cc855b71662b01e99ed905cc8ee53045e51f8f3fd9984f` |
| Slave MIF SHA-256 | `76b4aa079c6fe324a273199398189da87a542feed02209cb5f97c9c670caa8ca` | `46ab0bc2360121d356c671267dbcbd7a68bf700ed9a39451ed7f87cb89c3a20b` |
| Master SOF SHA-256 | `b3749c03338e4d61668ea69fffaa0da8b2c45fa991d4dbb24b92582768ffc0e2` | `04ae2dcf37592f08d3f1b4ca94c8f3865ecf720277339bae60234b60b1b815ea` |
| Slave SOF SHA-256 | `1424c50b2751945f65261de90929483503abd399e73a9157b07b67de3d45d727` | `dc849db47de731f57396dea0f4e173662577935af92cf867a4cecd2c8c085d68` |

The fit and timing reports remained byte-identical before and after the MIF
updates:

```text
MASTER fit.rpt SHA-256 = 0841aab085fe6a05632f7529a285fc3c9c633e041777ecd83c704ab50788ccce
MASTER sta.rpt SHA-256 = bc2678d0619b0259ba102b1c50ac922e752243fed93d4e7a61c5d93001cc362b
SLAVE  fit.rpt SHA-256 = e56f5a5e2e241fb2a4277dc4733f750a6557f8ec98f7ff1979fa569e8e4d00da
SLAVE  sta.rpt SHA-256 = 070634d2f1cbdc8a439b6ab07cf90f3cbdde4c81d556250c7f428f9432589c8e
```

Timing remains open from the canonical fit (`Master WNS=-0.050 ns`,
`Slave WNS=-0.266 ns`, `TIMING_CLOSED=NO`).

## Programming and Step4B preflight

Both A and B master/slave SOF programming operations succeeded with zero
programmer errors and zero warnings.

The first post-program preflight for each image had the known transient Slave
Step2 gate condition and was not counted.  The next three windows for each
image were consecutive settled trusted PASS:

```text
A kp=-300: preflight 2/3/4
B kp=-301: preflight 2/3/4

Master Step1/Step2/Step4A = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
RXERR_DELTA = 0
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

Raw preflight logs are preserved on pain under:

```text
artifacts/exp-step5-frozen-fit-20260902/preflight-kp300-2.log
artifacts/exp-step5-frozen-fit-20260902/preflight-kp300-3.log
artifacts/exp-step5-frozen-fit-20260902/preflight-kp300-4.log
artifacts/exp-step5-frozen-fit-20260902/preflight-kp301-2.log
artifacts/exp-step5-frozen-fit-20260902/preflight-kp301-3.log
artifacts/exp-step5-frozen-fit-20260902/preflight-kp301-4.log
```

Therefore Step4B is revalidated for both frozen-fit images.

## 600-second trusted observer results

Observer command for both images:

```text
quartus_stp -t read_step5_helper_pi_state_rail_audit.tcl 600 1000 "DE5 [1-11.2]" 0
```

### A: kp=-300, ki=-1

Raw log:
`artifacts/exp-step5-frozen-fit-20260902/observer-kp300-600s-run2.log`

```text
SAMPLES=600
VALID_FRAMES=600
INVALID_FRAMES=0
WINDOW_SECONDS=599.000
PI_TRACE_PRESENT=600
PI_SNAPSHOT_REJECTS=0
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
HELPER_ERROR_MEAN=51047.9773333
HELPER_ERROR_RMS=98736.2357457
LOW_RAIL_SAMPLES=232
LOW_RAIL_FRACTION=38.667%
HIGH_RAIL_SAMPLES=28
HIGH_RAIL_FRACTION=4.667%
NO_RAIL_FRACTION=56.667%
LOCK_COUNT_MAX=0
LOCK_COUNT_FINAL=0
HELPER_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
FREQ_ERROR_MEAN=193.003333333
FREQ_ERROR_RMS=304.051119605
FREQ_ERROR_MAX_ABS=520
FREQ_ZERO_CROSSINGS=86
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
TRANSACTION_ACCOUNTING=PASS
RESET_STABLE=PASS
ATOMIC_SNAPSHOT_TRANSPORT_V3=PASS
FROZEN_BANK_READ_STABILITY=PASS
```

### B: kp=-301, ki=-1

Raw log:
`artifacts/exp-step5-frozen-fit-20260902/observer-kp301-600s.log`

```text
SAMPLES=600
VALID_FRAMES=600
INVALID_FRAMES=0
WINDOW_SECONDS=599.000
PI_TRACE_PRESENT=600
PI_SNAPSHOT_REJECTS=0
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
HELPER_ERROR_MEAN=93016.9331667
HELPER_ERROR_RMS=118111.954525
LOW_RAIL_SAMPLES=372
LOW_RAIL_FRACTION=62.000%
HIGH_RAIL_SAMPLES=0
HIGH_RAIL_FRACTION=0.000%
NO_RAIL_FRACTION=38.000%
LOCK_COUNT_MAX=0
LOCK_COUNT_FINAL=0
HELPER_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
FREQ_ERROR_MEAN=309.163333333
FREQ_ERROR_RMS=393.527889736
FREQ_ERROR_MAX_ABS=535
FREQ_ZERO_CROSSINGS=53
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
TRANSACTION_ACCOUNTING=PASS
RESET_STABLE=PASS
ATOMIC_SNAPSHOT_TRANSPORT_V3=PASS
FROZEN_BANK_READ_STABILITY=PASS
```

Both images therefore exercised the runtime path and produced valid trusted
measurements, but neither reached the Step5 hard gate
`HELPER_LOCK_COUNT_MAX > 0`.

## Verdict

```text
STEP4B_COMPLETE=YES
STEP4B_REVALIDATED=YES
FROZEN_FIT_MIF_ONLY_AB=PASS
KP_MINUS300_LOCK_COUNT_MAX=0
KP_MINUS301_LOCK_COUNT_MAX=0
STEP5_COMPLETE=NO
MERGE_APPROVED=NO
```

This experiment confirms that the earlier `Step4B` result is genuine for both
images and that the unchanged fitted hardware is not the source of an A/B
fit difference.  It does not satisfy Step5, so no merge authorization is
requested from GitHub until the branch-5 reviewer provides a new decision.
