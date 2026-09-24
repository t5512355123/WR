# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-ATOMIC-DIAG-SNAPSHOT-REPEAT-20260901

Date: 2026-09-01 (Asia/Taipei)
Branch: `exp/step5-softpll-lock`
Experiment status: `INCOMPLETE_PRECONDITION`

## Purpose

Re-run the branch5-specified `ki=-1` Step5 experiment after adding the
diagnostic-only PI source epoch guard and rebuilding the firmware MIFs. The
100-sample atomic snapshot smoke is allowed only after three clean runtime
preflight dashboards.

## Baseline and allowed change

- Functional baseline: `bootstrap=6176`, `code_per_physical_step=64`,
  `kp=-150`, `ki=-1`, `threshold=200`, `lock_samples=10000`.
- Control, tracker, DMTD, P_SETPOINT, anti-windup, sequencer, and reset logic
  were not changed.
- Diagnostic-only source guard from `c8fd8f1` brackets the stable PI trace
  copy with the PI source `trace_epoch` and rejects a torn source snapshot.
- Current evidence tip: `3df2202`.

## Build and programming evidence

Firmware was rebuilt before the Quartus JTAG builds. Both JTAG full
compilations succeeded and both fresh-program operations completed with
0 errors and 0 warnings.

```text
MASTER_MIF_SHA256 = 3ffd152e634cc8a2309824444030f00e12ca2c8f2dc5476da16df5c6c2b97056
SLAVE_MIF_SHA256  = b47636ba74f1abe3a20c2cfdd29bff4bc0eed635dcd454efddb1e578dc3495ad
MASTER_SOF_SHA256 = 01efef210ec31cdc710f3d85b446795707733f8b93a1fb5e753d0a16498d01861
SLAVE_SOF_SHA256  = ede7b2fa7f3915cb48e68121b790c330aa22dd28d71ef385cfb432ba18eec2649
MASTER_PROGRAM    = PASS (DE5 [1-11.1], 0 errors, 0 warnings)
SLAVE_PROGRAM     = PASS (DE5 [1-11.2], 0 errors, 0 warnings)
```

## Runtime preflight result

Raw logs are on the pain build host under:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-ATOMIC-DIAG-SNAPSHOT-REPEAT-20260901/`

The first three samples after programming still showed `PPS_UNCALIBRATED`
(`state=8`). After a longer wait, the Slave reached `state=9 SLAVE`, but the
endpoint gate became intermittent because `WDIAGS_RXERR` sometimes increased
during the dashboard observation window.

```text
preflight-07..09: PTP state=8 UNCALIBRATED; STEP2 error; STEP4B blocked
preflight-10:    PTP=SLAVE; WDIAGS_RXERR delta=4; STEP2 error; STEP4B blocked
preflight-11:    PTP=SLAVE; WDIAGS_RXERR delta=2; STEP2 error; STEP4B blocked
preflight-12:    PTP=SLAVE; WDIAGS_RXERR delta=4; STEP2 error; STEP4B blocked
preflight-13:    PTP=SLAVE; WDIAGS_RXERR delta=0; STEP2 pass; STEP3 pass; STEP4B pass
preflight-14:    PTP=SLAVE; WDIAGS_RXERR delta=2; STEP2 error; STEP4B blocked
preflight-15:    WDIAGS_RXERR delta=3; STEP4B blocked
preflight-16:    WDIAGS_RXERR delta=3; STEP4B blocked
preflight-17:    WDIAGS_RXERR delta=1; STEP4B blocked
preflight-18:    WDIAGS_RXERR delta=1; STEP4B blocked
preflight-19:    WDIAGS_RXERR delta=0; STEP2 pass; STEP3 pass; STEP4B pass
preflight-20:    WDIAGS_RXERR delta=3; STEP4B blocked
preflight-21:    WDIAGS_RXERR delta=0; STEP2 pass; STEP3 pass; STEP4B pass
preflight-22:    WDIAGS_RXERR delta=1; STEP4B blocked
```

The accumulated RXERR raw counter rose from `0x4F` to approximately
`0x90` during the retry batch. This is not a clean three-dashboard preflight
set; therefore the 100-sample smoke was intentionally not started.

## Decision

```text
PREFLIGHT_3_CLEAN = NO
ATOMIC_SMOKE_100 = NOT_RUN
STEP4B_REVALIDATED_BY_THIS_RUN = NO (gate intermittently blocked)
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This run does not adjudicate the `ki=-1` closed-loop dynamics. The immediate
boundary is an intermittent `WDIAGS_RXERR`/dashboard endpoint gate after
fresh programming, not a PI snapshot result. No control parameter was changed
in response.

## Next action for branch5 review

Determine whether to treat the intermittent RXERR as a physical/link
precondition that must be cleared first, or specify the smallest diagnostic
experiment to distinguish link errors from dashboard/JTAG measurement error.
After three clean preflight dashboards, resume the already-approved sequence:
run the 100-sample atomic smoke, and proceed to the 1800-second `ki=-1` run
only if all smoke acceptance counters pass.
