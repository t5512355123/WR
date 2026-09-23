# Report — EXP-S6-ENDPOINT-LINK-AUTO-RECOVERY-20260923

## Verdict

```text
STEP1_PHY_LINK                         = PASS (84/84 board frames)
STEP2_ENDPOINT_PTP                     = PARTIAL (68 PASS, 16 INFO, 0 FAIL)
STEP3_WR_HANDSHAKE                     = ROLE-EXPECTED (42 PASS, 42 INFO)
STEP4_SOFTPLL_STARTUP                 = PARTIAL (68 PASS, 16 INFO, 0 FAIL)
STEP5_FIVE_DIRECT_LOCKS_300S           = NOT_PASS (only 21/42 Slave frames all asserted)
STEP6_MASTER_GLOBAL_TIME               = PASS (42/42 frames)
STEP6_SLAVE_GLOBAL_TIME                = NOT_PASS (42/42 WAITING)
ENDPOINT_RECOVERY_MILESTONE            = NOT_REACHED
```

The read-only dashboard capture contains 42 paired samples from
`2026-09-23T22:27:50+08:00` through `2026-09-23T22:34:41+08:00` (nominal
10-second sampling; 411 seconds between first and last sample). Both boards
reported Step 1 PHY/link PASS in all 42 samples. The aggregate Step 2 and Step 4
lines contain 68 PASS and 16 INFO results each; the raw capture has no FAIL
result in those gates. Step 3 is role-dependent: Slave PASS and Master INFO in
all 42 samples.

On the Slave, all five direct Step 5 indicators were simultaneously asserted in
only 21 of 42 samples; the longest uninterrupted run was 21 samples spanning
200 seconds. The dashboard classified 21 samples as
`LOCK_ACQUIRED_NOT_STABLE`, 5 as `NEVER_LOCKED`, and 16 as
`UPSTREAM_NOT_READY`. This cannot establish the required 300-second continuous
lock window.

Global Time was asymmetric: Master was VALID in all 42 samples, while Slave was
WAITING with `TIME_VALID=0` and `PPS_VALID=0` in all 42 samples. Therefore this
run did not pass Step 6A, even though the link gate recovered.

## Diagnosis supported by the capture

The endpoint-retry change restored the Step 1 link gate, so this run does not
support blaming the optical path for the remaining failure. The later Slave
attribution capture records `WR_FAILURE_REASON=3` (S_LOCK timeout),
`WR_DISABLE_PTP_STATE=8`, `PTP_STATE=9`, and `WR_STATE_VALUE=0` while the link
remains healthy and the global-time snapshot remains invalid. Endpoint recovery
alone was insufficient: the remaining boundary was the Slave WR/PTP handshake
and time-servo lifecycle after link-up.

This evidence motivated the subsequent narrowly-scoped S_LOCK re-arm experiments.
It does not establish a Step 5 or Step 6 milestone.

## Build artifacts

The two `fb0d038b` SOFs were intermediate experiment images, not the final
reproducible milestone, so their binaries are intentionally not retained in the
repository. Their exact SHA-256 values are preserved in
[`raw/prior-build-sof-manifest.sha256`](raw/prior-build-sof-manifest.sha256).
The final Step 6 milestone SOFs remain in the canonical `artifacts/` directory
and are identified in the Step 6 pass-milestone report.

## Raw evidence

- `raw/extension-state-attribution.log`
- `raw/postprogram-smoke.log`
- `raw/slave-tmvalid-attribution.log`
- `raw/stability-420s.log`
- `raw/prior-build-sof-manifest.sha256`
