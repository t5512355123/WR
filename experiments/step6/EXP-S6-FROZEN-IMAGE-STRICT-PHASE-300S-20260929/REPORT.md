# EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929 — report

## Verdict

```text
FROZEN_STEP6_IMAGES_PROGRAMMED                  = PASS
STEP1_LINK_RECOVERED                            = PASS (after startup settling)
SLAVE_STEP5_LOCKS_OBSERVED                      = 110/110 consecutive samples over 1091 s
GLOBAL_TIME_VALID                               = MASTER 143/143; SLAVE 105/143
STRICT_SLAVE_OFFSET_POINT                       = PASS once (-17 ps, TRACK_PHASE)
STRICT_OFFSET_STABILITY_300S                    = NOT_ESTABLISHED
STEP6_EXPANDED_ACCEPTANCE                       = NOT_ESTABLISHED
HISTORICAL_STEP6A_AND_STEP6B_DIGITAL_EVIDENCE   = PRESERVED, NOT RE-RUN
```

The exact frozen Step 6 images programmed successfully, and the system
eventually recovered link, all five Slave lock indicators, and valid/stable
Global-Time snapshots. There was one qualifying sample at `2026-09-29
20:39:48+08:00`: the Slave offset was `-17 ps` and the WR servo reported
`TRACK_PHASE`. The next dashboard sample, 10 seconds later, showed
`+1165 ps` and `WAIT_OFFSET_STABLE`. Across the 105 Slave frames with valid
Global Time, only 1 was strictly inside `(-60,+60) ps`; the longest consecutive
qualified run was one sample. Therefore this run does **not** establish the
expanded Step 6 gate and the planned 300-second strict-gate window was not
started.

## Exact source and images

- Branch: `feat/file_cleanup`.
- Pain source commit at programming: `bb3ead3c93296c22d682b52eae6f684862c0af58`.
- Git tree at programming: `2ccbda8343777c956408f8e5d41abfb8c2044508`.
- Master SOF:
  `artifacts/milestones/step6_global_time/master.sof`, SHA-256
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Slave SOF:
  `artifacts/milestones/step6_global_time/slave.sof`, SHA-256
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Source and milestone manifests were verified on Pain before programming.
- No code, RTL, firmware, PLL parameter, or timing constraint was modified for
  this hardware run. No physical power cycle or separate reset was performed.

## Programming and initial smoke

Programming order was Slave, then Master, using the milestone wrappers and
their intended cables:

| Board | Cable | Result | Quartus time |
|---|---|---|---|
| Slave | `DE5 [1-11.2]` | 1 device configured; 0 errors, 0 warnings | 20:26:15–20:26:34 |
| Master | `DE5 [1-11.1]` | 1 device configured; 0 errors, 0 warnings | 20:26:53–20:27:12 |

The immediate dashboard smoke at 20:27:42 (30 seconds after Master
programming) showed `Link=0 / TM=0` on both boards. This was transient, not a
persistent regression: a read-only settling capture later observed Step 1/link
PASS on both boards. The smoke is retained in `raw/observe/smoke.log`.

## Read-only startup settling observation

- Dashboard cadence setting: 10 seconds; per-board comparison window: 2000 ms.
- Complete frames: 143, from `20:33:29` through `20:57:09+08:00`, a span of
  1420 seconds. One final frame was interrupted at the fixed 20:57:12 deadline
  and is excluded from all counts.
- Master link and Global Time: 143/143 complete frames.
- Slave link and valid/stable Global Time: 105/143 frames; the first fully
  valid Slave time sample was at `20:39:48+08:00`.
- All five Slave indicators (Helper, Main frequency, Main phase, Main lock,
  PSTAT) were 1 in 110 consecutive sampled frames from `20:38:58` through
  `20:57:09+08:00`, a 1091-second span. This is a sampled observation; the
  previously validated Step 5 300-second milestone remains the formal Step 5
  reproduction evidence.
- Among the 105 valid/stable Slave time samples, offset ranged from `-4006 ps`
  to `+2417 ps`, with median `+661 ps`. Exactly one sample met the strict
  `<60 ps` limit: `-17 ps` at `20:39:48`, state `TRACK_PHASE`.
- The observed Slave servo-state counts were: `SYNC_TAI` 33,
  `SYNC_PHASE` 9, `WAIT_OFFSET_STABLE` 100, and `TRACK_PHASE` 1.
- There was one `DASHBOARD_ERROR` on the final, deliberately interrupted frame
  when the 30-minute startup deadline sent SIGINT to Quartus. The 143 complete
  frames had no reader/JTAG error. The timeout exit status was 124 and the
  interrupted final frame is not treated as hardware failure evidence.

Raw dashboard log: `raw/observe/startup_settling.log`. The machine-readable
summary is reproducible with `analysis/summarize_dashboard.py`; its two offline
tests pass.

## Source-grounded interpretation

The frozen WRPC source defines `WRH_SERVO_OFFSET_STABILITY_THRESHOLD` as 60 ps
in `artifacts/milestones/step6_global_time/source/vendor/wrpc-sw/ppsi/include/hw-specific/wrh.h:56`.
In `.../ppsi/proto-ext-common/wrh-servo.c:303-306`,
`WRH_WAIT_OFFSET_STABLE` enters `WRH_TRACK_PHASE` only when the remaining phase
offset is below that threshold. In `wrh-servo.c:321-323`, tracking returns to
`WRH_SYNC_PHASE` when `abs(offset_ps) > 2 * 60 ps`. The captured sequence is
consistent with one brief entry into `TRACK_PHASE` followed by renewed
acquisition, but the 10-second dashboard cadence does not reveal the exact
intermediate transition or its cause.

## Next action — no consultant

Proceed directly with a bounded, read-only high-rate servo-transition
correlation using the existing frozen-source
`scripts/jtag/read_wb_timeseries_session.tcl`. It already records CKO, SETP,
DMS, UCNT, servo state, PTP status, and SoftPLL lock fields through the
existing diagnostic read mailbox; source audit confirms it does not write WR
settings or the `DATA_SNAPSHOT` register. Capture enough samples to resolve the
10-second blind interval around a `TRACK_PHASE` entry/exit. Do not change the
frozen image, servo threshold, control gains, timing constraints, or clock
settings until the transition trace identifies a source-supported cause.

## Reproduction and integrity

- Dashboard gate regression suite: 12/12 passed on Pain.
- New offline log-summary tests: 3/3 passed locally. The analyzer requires both at least 25 consecutive qualified frames and an actual qualifying span of at least 300 seconds before returning expanded Step 6 observation PASS.
- `bash -n scripts/monitor/step1_6_dashboard.sh`: passed on Pain.
- Raw file SHA-256 values are recorded in `raw/SHA256SUMS`.
- The archive `/home/b10504072/04_WR_archive_step6_pass/` was not accessed for
  writing or modified.
