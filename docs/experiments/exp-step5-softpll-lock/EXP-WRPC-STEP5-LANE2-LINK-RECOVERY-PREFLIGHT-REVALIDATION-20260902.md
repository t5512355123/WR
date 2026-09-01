# EXP-WRPC-STEP5-LANE2-LINK-RECOVERY-PREFLIGHT-REVALIDATION-20260902

## Verdict

This is a recovery/preflight experiment for the existing `kp=-310` image. It intentionally changed no controller parameter and did not run the Step 5 600-second dynamics window.

```text
branch = exp/step5-softpll-lock
current HEAD = 79df580
CONTROL_VARIABLE = NONE
kp image retained = -310
STEP4B_COMPLETE = YES              # historical validated result
STEP4B_REVALIDATED = YES           # historical validated result
CURRENT_KP_MINUS310_PREFLIGHT = INVALID_FOR_STEP5_DYNAMICS
KP_MINUS310_DYNAMICS_VERDICT = NOT_OBSERVED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Recovery actions

The `kp=-310` Master and Slave images were already built successfully and were programmed repeatedly in the established Slave-first, Master-second order. A second fresh-program was also performed with an explicit delay between the two boards.

The known short post-program transient was excluded. Multiple subsequent preflight retries showed that the link could return, but the Slave continued to accumulate non-zero `RXERR` during the observation window or remained `UNCALIBRATED`. Therefore none of these retries is a valid Step 5 observation window.

Representative raw logs:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-INITIAL.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY1.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY2.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY3.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY4.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY5.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY6.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY7.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY8.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY9.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-PREFLIGHT-RETRY10.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-LINK-RECOVERY-PREFLIGHT-RETRY11-20260902.log
```

Read-only RX attribution logs:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-RX-ERROR-ATTRIBUTION-QUIET-60S.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS310-KI-MINUS1-LANE2-RX-ERROR-ATTRIBUTION-DASHBOARD-60S.log
```

## Observed blocker

The recurring failure boundary was upstream of Step 4B:

```text
WDIAGS_PTP = UNCALIBRATED or invalid during retry
Slave RXERR delta != 0 during retry
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1 or BLOCKED_BY_STEP2
```

The JTAG/Wishbone diagnostic transport itself remained healthy in the same observations:

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
DMTD_REF_DECREASE_COUNT = 0
DMTD_FB_DECREASE_COUNT = 0
```

This is therefore an external lane/link recovery blocker, not evidence that `kp=-310` caused a Step 4B regression. No `kp=-310` helper dynamics result was recorded, and no 600-second Step 5 run was started.

## Additional retry11 observation

After another 20-second settled delay, the read-only runtime diagnostic again showed an asymmetric result:

```text
Master Step1 = PASS
Master Step2 = PASS
Master Step4A = PASS
Master RXERR_DELTA = 0

Slave Step1 = PASS
Slave Step2 = ERROR
Slave WDIAGS_PTP = UNCALIBRATED
Slave RXERR_DELTA = 6
Slave Step3 = PASS
Slave STEP4B_ALLOWED = NO
Slave STEP4B_RESULT = BLOCKED_BY_STEP2

PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

This confirms the dashboard's repeated `Step 1/Step 4` error presentation is an upstream Slave endpoint/link-quality failure in the current observation, not a new SoftPLL startup failure. The Master remains healthy and the diagnostic transport remains trusted.

## Required next gate

Keep the existing `kp=-310` image and all controller settings unchanged. First restore/verify the QSFP-A lane2 external path, then obtain three consecutive settled preflight passes:

```text
Master/Slave Step1 = PASS
Master/Slave Step2 = PASS
Slave Step3 = PASS
Master Step4A = PASS
Slave STEP4B_ALLOWED = YES
Slave STEP4B_RESULT = PASS
Master RXERR_DELTA = 0
Slave RXERR_DELTA = 0
WDIAGS_PTP = calibrated/valid
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

Only after those three passes should the same `kp=-310` image be used for the 600-second Step 5 dynamics run.
