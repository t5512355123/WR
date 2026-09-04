# EXP-WRPC-COLD-BOOT-PROGRAM-ORDER-MASTER-THEN-SLAVE-UPSTREAM-RECOVERY-20260904

## Result (executed 2026-09-05, Asia/Taipei)

Reversing programming order did **not** restore the upstream link. Following
the user's new confirmation that both boards had been physically power-cycled,
the exact frozen-fit images were programmed Master first, then Slave. Both
programming operations succeeded. All five subsequent read-only preflights
failed Step1 on both boards; Slave Step4B remained blocked by Step1.

```text
ONLY_INTENTIONAL_CONTROL_VARIABLE = PROGRAMMING_ORDER
PROGRAM_ORDER = MASTER_THEN_SLAVE
COLD_POWER_CYCLE = CONFIRMED_BY_USER
FRESH_PROGRAM = PASS
SETTLED_PREFLIGHT_PASSES = 0/5
THREE_CONSECUTIVE_PREFLIGHT_PASSES = NO
MASTER_STEP4A = PASS (5/5)
STEP4B_COMPLETE = YES (historical milestone, not this run)
STEP4B_REVALIDATED = NO
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
HELPER_600S = NOT_RUN_UPSTREAM_GATE_FAIL
CURRENT_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP1
```

The current result is not a Step5 controller test. Neither a Helper 600-second
run nor a Main-DAC experiment was performed. No merge was performed.

## Provenance and controls

- Experiment identifier retains the date requested by branch5; execution was
  on September 5, not September 4.
- Branch: `exp/step5-softpll-lock`.
- Runner/observer HEAD: `e45e4230f79585f4e8853c1bd84dc323d89e0634`.
- Image source: `88604a5` plus `7585a06` Main-trace publication-only patch,
  reusing the previously validated frozen-fit images. No rebuild.
- Lane 2, fiber connection, RTL, firmware, PI parameters and roles unchanged
  by this run. No role reinjection, reset command, or cable manipulation.
- Slave Helper: bootstrap 6208, code-per-physical-step 16, kp -300, ki -1,
  threshold 200, lock samples 10000.
- The prior cold-cycle report's kp -150 was a documentation error, corrected
  in e45e423 using `CONFIG_WR_NODE` source and the original image report;
  no image was changed to make the correction.
- Physical cold-cycle evidence is the user's confirmation, not an inference
  from filesystem timestamps or hashes. No independent power telemetry exists.

Exact images (checked before programming):

```text
Master / DE5 [1-11.1]
23bfdc100fa2b61aff3096754ebd99d61c1e1c1728be99cd5515204415c7dd0d
Slave / DE5 [1-11.2]
04c7cb7ecca19be16eb9de022891a9c0143b2c6b62ce364d80db4e56508217fc
```

The image directory on pain was:

```text
artifacts/exp-step5-frozen-fit-20260902/staging-88604a5-maintrace-run-20260902/quartus/jtag_runtime_diag/
  output_files_master_jtag/DE5a_wr_master_jtag.sof
  output_files_slave_jtag/DE5a_wr_slave_jtag.sof
```

## Programming and observation timeline

Quartus Prime Pro 21.3 programmed Master at 07:36:22–07:36:42, then Slave at
07:37:28–07:37:46. Both logs report configuration success, zero errors and
zero warnings. The inter-program gap was exactly 46 seconds, matching the
previous run's first-completion to second-start interval.

After Slave completion the runner waited 24 seconds before launching the
observer, matching the previous nominal settled interval. Quartus processing
started 26 seconds after completion (two seconds of launch overhead; previous
run's recorded interval was 24 seconds). Subsequent runs were separated by at
least 30 seconds without hardware intervention.

| Preflight | Processing window (+08:00) | Master TX/RX ready | Slave TX/RX ready | Master/Slave core link | Slave Step4B |
| --- | --- | --- | --- | --- | --- |
| 1 | 07:38:12–07:38:28 | 0 / 1 | 0 / 1 | 0 / 0 | BLOCKED_BY_STEP1 |
| 2 | 07:39:09–07:39:24 | 0 / 1 | 0 / 1 | 0 / 0 | BLOCKED_BY_STEP1 |
| 3 | 07:39:54–07:40:09 | 0 / 1 | 0 / 1 | 0 / 0 | BLOCKED_BY_STEP1 |
| 4 | 07:40:46–07:41:01 | 0 / 1 | 0 / 0 | 0 / 0 | BLOCKED_BY_STEP1 |
| 5 | 07:41:32–07:41:47 | 0 / 1 | 0 / 1 | 0 / 0 | BLOCKED_BY_STEP1 |

Readiness values are the displayed snapshots, not claims of continuous state
between observations. Each preflight contains its own before/after raw snapshot
and nominal five-second activity interval. `core_tm_link_up`, `core_link_ok`,
and `wr_ready` were all zero on both boards in every displayed preflight.

## Evidence and interpretation

Across all five runs:

- Diagnostic path: `PRELOAD_PROTOCOL_RUNTIME_REVALIDATION=PASS` and
  `JTAG_WB_DIAGNOSTIC_PATH=TRUSTED`; all observers completed without errors.
- Both boards: PTP_RX delta 0 and WDIAGS_RXERR delta 0. A zero error delta with
  no received packets does not establish a healthy physical link.
- Master stayed in PTP MASTER; Slave stayed in LISTENING, with no WR parent,
  `LOCK_ENABLE=0`, `spll_init_count=0`, and no TAG/TRR/IRQ/Helper activity.
- Master Step4A remained PASS, independently of failed PHY/link prerequisites.
- Both boards' boot generation, CPU reset count, WR-core reset count, and
  SI-config-drop count were 1 in all before/after snapshots: observed deltas 0.
  `si_config_done=1`; the counters do not claim zero lifetime reset events.
- `wr_rx_enc_err` was a high **flag** on both boards in preflights 1, 2, 3, 5;
  Slave's flag was 0 when its RX-ready bit was 0 in preflight 4. This flag is
  not the WDIAGS_RXERR packet-error counter and must not be reported as one
  counted error.

Compared with the previous Slave-then-Master cold run, this run did not recover
Step1. Moreover, Slave TX-ready was now also zero, so the latest observation
must not be reduced to the previous single-direction Master-TX/Slave-RX pattern.
The hypothesis that reversing programming order alone restores the link is
not supported by this trial. A single failed trial does not exclude every
possible startup-order dependence or establish the transceiver root cause.

The next useful boundary is PHY/transceiver readiness and reset/clock bring-up,
not PI tuning. Request branch5's next scoped experiment using these fresh raw
results; retain `STEP5_COMPLETE=NO` and `MERGE_APPROVED=NO`.

## Raw evidence

All raw files are under:

```text
raw/EXP-WRPC-COLD-BOOT-PROGRAM-ORDER-MASTER-THEN-SLAVE-UPSTREAM-RECOVERY-20260904/
  metadata.txt
  sof-sha256.txt
  program-timeline.log
  program-master.log
  program-slave.log
  preflight-1.log
  preflight-2.log
  preflight-3.log
  preflight-4.log
  preflight-5.log
```

The raw files were copied from pain to the laptop before this report was
written. Prior untracked cold-run files on pain were preserved under
`artifacts/preserved-cold-before-e45e423-20260905/` before pulling their tracked
copies; unrelated files were not cleaned or reset.
