# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-COLD-POWER-CYCLE-HELPER-REACQUISITION-600S-20260902

## Result

The user confirmed that a true physical cold power cycle was completed. The
previously validated, exact Slave and Master SOFs were then programmed in the
required Slave -> Master order. Both programming operations succeeded, but the
post-programming upstream gate never became valid: five preflight attempts and
one focused 20-sample handshake observation all showed `core_tm_link_up=0` and
`core_link_ok=0` on both boards.

The required 600-second Helper observer was therefore **not run**. Branch5's
rule requires three consecutive settled preflight passes before starting it;
starting it in this state would not be a valid Step5 Helper reacquisition test.

```text
COLD_POWER_CYCLE = CONFIRMED_BY_USER
FRESH_PROGRAM = PASS
PROGRAM_ORDER = SLAVE_THEN_MASTER
SETTLED_PREFLIGHTS_REQUIRED = 3
SETTLED_PREFLIGHTS_OBTAINED = 0
HELPER_REACQUISITION_600S = NOT_RUN_UPSTREAM_GATE_FAIL

STEP4B_COMPLETE = YES                  (previous validated baseline)
STEP4B_REVALIDATED = NO                (this cold run)
STEP4B_RESULT_THIS_RUN = BLOCKED_BY_STEP1
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Fixed provenance

```text
branch = exp/step5-softpll-lock
observer_commit = d8a4d3fa018033dfc469058f077509a77ffbf16a
image_source = 88604a5 + 7585a06 (previously validated frozen-fit image)
QSFPA data path = lane 2
bootstrap = 6208
code_per_physical_step = 16
kp = -150
ki = -1
helper_threshold = 200
helper_lock_samples = 10000
```

The physical-cycle evidence timestamp recorded immediately before programming
was `2026-09-04T10:59:56+08:00`.

Exact SOF hashes:

```text
Slave = 04c7cb7ecca19be16eb9de022891a9c0143b2c6b62ce364d80db4e56508217fc
Master = 23bfdc100fa2b61aff3096754ebd99d61c1e1c1728be99cd5515204415c7dd0d
```

Programming used:

```text
Slave cable = DE5 [1-11.2]
Master cable = DE5 [1-11.1]
Slave start = 2026-09-04 11:01:28
Master start = 2026-09-04 11:02:31
both = Configuration succeeded; 0 errors, 0 warnings
```

No firmware, RTL, PI parameter, PHY, PTP role, or observer-control change was
made for this hardware-state experiment.

## Preflight gate

All five attempts (`preflight-1` through `preflight-5`) returned the same
formal outcome:

```text
Master Step1 = FAIL
Master Step4A = PASS
Slave Step1 = FAIL
Slave Step4B_ALLOWED = NO
Slave Step4B_RESULT = BLOCKED_BY_STEP1
Slave Step5_RESULT = UPSTREAM_NOT_READY
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
RXERR delta = 0
CPU reset delta = 0
WR-core reset delta = 0
```

The final preflight (`preflight-5`) showed:

```text
Master: wr_ready=0, core_tm_link_up=0, core_link_ok=0,
        wr_rx_ready=1, wr_tx_ready=0, wr_rx_enc_err=0,
        WDIAGS_PTP=MASTER, PTP_RX delta=0

Slave:  wr_ready=0, core_tm_link_up=0, core_link_ok=0,
        wr_rx_ready=0, wr_tx_ready=1, wr_rx_locked_to_data=0,
        wr_rx_enc_err=0, WDIAGS_PTP=LISTENING,
        parentIsWRnode=0, parentCalibrated=0, LOCK_ENABLE=0
```

The Slave's readiness bits were transient during earlier captures, but the
timing link and link-check bits never became 1. The final post-health capture
also showed Slave `spll_state=0`, `spll_init_count=0`, `PSTAT=0`, and no new
TAG/TRR/IRQ/Helper activity because the Step4B upstream prerequisite was never
met.

## Focused handshake observation

The read-only focused observer collected 20 valid samples for each board with
zero invalid samples:

```text
Master: PTP_TX_DELTA=63, PTP_RX=0, parent=0/0/0,
        STEP2_REGRESSION=FAIL, signal_good=0
Slave:  PTP_TX_DELTA=12, PTP_RX=0, parent=0/0/0,
        STEP2_REGRESSION=FAIL, STEP3_REGRESSION=FAIL,
        signal_good=0, state_idle=20
```

This is an upstream link/parent bring-up failure, not evidence that the Step5
Helper controller or Main-DAC closed loop failed. Since the valid preflight
window never reappeared, no Helper lock count, Helper error distribution, rail
fraction, Main-enable observation, or 600-second Step5 result exists for this
run.

## Raw evidence

```text
raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-COLD-POWER-CYCLE-HELPER-REACQUISITION-600S-20260902/
  cold-power-cycle-confirmed-at.log
  sof-sha256.txt
  program-slave.log
  program-master.log
  preflight-1.log
  preflight-2.log
  preflight-3.log
  preflight-4.log
  preflight-5.log
  wr-handshake-focused-20s.log
  post-health.log
```

## Handoff to branch5-WR

The cold power-cycle variable was exercised, but it did not produce the
required upstream gate. The next experiment must be selected by branch5-WR;
do not claim Step5 PASS or merge this branch into `main`.
