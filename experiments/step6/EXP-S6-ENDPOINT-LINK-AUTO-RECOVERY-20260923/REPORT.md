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

## Retrospective identification of the 2026-09-23 21:30 failure capture

The user-shared terminal commands programmed SOFs from
`/home/b10504072/step6-wr-rearm-fb0d038b/`. The prior-build manifest in this
experiment binds that worktree's intermediate images to:

```text
Master = 45a671b75bacfc98859e97006098a59c3fed460a5186884439e41a0bec75de8f
Slave  = db8ec57f4b53b784585f83880774e5eb2a11069cbd8d3ef921eed4e1270de6a6
```

Those images came from source commit `fb0d038bd4bbe5ffc37fcc4d5e441ede039bf5ca`;
they are not the final retained Step6 pair. The later commit
`fbf22f24` (`fix: retry persistent DE5a endpoint link failures`) added bounded
firmware endpoint re-initialization in `vendor/wrpc-sw/wrc_main.c`. A separate
dashboard correction then stopped treating a retained Master time snapshot as
Step6 PASS while Step1 link was down. The subsequent Step6 re-arm fixes were
included in source commit `74dc28862653d306e0450cf437ba6d3a230d979d`.

The later endpoint-recovery capture reports Step1 PASS in all 84 board frames;
the final Step6 report records Step1 through Step6 passing with the retained
`6521eb...` Master / `4775de...` Slave images. This shows the 21:30 output did
not test the final endpoint-retry image and explains its `Link=0` plus stale
Master `TIME_VALID` display. The evidence supports a firmware/startup recovery
issue rather than a fiber fault; it does not establish that a physical link
could never fail for another reason.

The pasted command order was Master then Slave, whereas the successful final
Step6 report used Slave then Master. No controlled order-only A/B is present,
so the order difference is recorded as a caution, not as a separately proven
root cause. For the retained final pair, use the order in its report.

The source lineage is confirmed in Git: `fbf22f24681d0851140036d8f59e0a1bedc38e8f`
is an ancestor of the current `feat/file_cleanup` HEAD, and contains the
bounded retry shown above. The final Step6 source commit
`74dc28862653d306e0450cf437ba6d3a230d979d` is also in that branch's history.
